//
//  VoiceService.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import Foundation
import Speech
import AVFoundation
import SwiftUI
import Combine

/// Service for voice input (speech-to-text)
@MainActor
class VoiceService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var transcription = ""
    @Published var errorMessage: String?
    
    // MARK: - Speech Recognition
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Initialize speech recognizer with legal-friendly locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        // Request permissions
        requestPermissions()
    }
    
    // MARK: - Permissions
    
    func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.errorMessage = nil
                case .denied, .restricted, .notDetermined:
                    self?.errorMessage = "Speech recognition permission denied"
                @unknown default:
                    self?.errorMessage = "Unknown speech recognition permission status"
                }
            }
        }
        
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.errorMessage = "Microphone permission denied"
                }
            }
        }
    }
    
    // MARK: - Speech-to-Text
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Check permissions
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            errorMessage = "Speech recognition not authorized"
            requestPermissions()
            return
        }
        
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            errorMessage = "Microphone permission not granted"
            requestPermissions()
            return
        }
        
        // Stop any existing recognition
        stopRecording()
        
        // Reset transcription
        transcription = ""
        errorMessage = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Failed to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.transcription = result.bestTranscription.formattedString
            }
            
            if let error = error {
                self.errorMessage = "Recognition error: \(error.localizedDescription)"
                self.stopRecording()
            }
            
            // Check if final result
            if result?.isFinal == true {
                self.stopRecording()
            }
        }
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            HapticManager.shared.startRecording()
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            stopRecording()
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        isRecording = false
        HapticManager.shared.stopRecording()
    }
    
    // MARK: - Cleanup
    
    // Note: Cleanup is handled automatically when the service is deallocated
    // Cannot call @MainActor methods from deinit, so cleanup happens naturally
}
