//
//  SelectableTextView.swift
//  lawgpt
//
//  Created for better text selection support with links
//

import SwiftUI
import UIKit

// Custom UIView wrapper to properly handle UITextView sizing
class ConstrainedTextView: UIView {
    private let internalTextView: UITextView
    var textView: UITextView { internalTextView }
    weak var delegate: UITextViewDelegate? {
        didSet {
            internalTextView.delegate = delegate
        }
    }
    
    var attributedText: NSAttributedString? {
        get { internalTextView.attributedText }
        set {
            internalTextView.attributedText = newValue
            invalidateIntrinsicContentSize()
        }
    }
    
    init() {
        internalTextView = UITextView()
        super.init(frame: .zero)
        
        internalTextView.isEditable = false
        internalTextView.isSelectable = true
        internalTextView.isScrollEnabled = false
        internalTextView.backgroundColor = .clear
        
        // CRITICAL: Configure text container to respect width constraints
        let textContainer = internalTextView.textContainer
        textContainer.widthTracksTextView = true // Automatically track textView's width
        textContainer.heightTracksTextView = false // Don't track height
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        
        internalTextView.textContainerInset = .zero
        internalTextView.textContainer.lineFragmentPadding = 0
        
        internalTextView.font = UIFont.systemFont(ofSize: 17)
        internalTextView.textColor = UIColor.label
        internalTextView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        
        addSubview(internalTextView)
        internalTextView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            internalTextView.topAnchor.constraint(equalTo: topAnchor),
            internalTextView.leadingAnchor.constraint(equalTo: leadingAnchor),
            internalTextView.trailingAnchor.constraint(equalTo: trailingAnchor),
            internalTextView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        // Calculate size based on frame width or fallback width
        let width = frame.width > 0 ? frame.width : (UIScreen.main.bounds.width - 48)
        let size = internalTextView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return size
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // When widthTracksTextView is true, the text container automatically adjusts to textView's bounds
        // Just ensure the textView is properly laid out
        internalTextView.layoutIfNeeded()
    }
}

struct SelectableTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    @Binding var showSafari: Bool
    @Binding var safariURL: URL?
    
    func makeUIView(context: Context) -> ConstrainedTextView {
        let wrapper = ConstrainedTextView()
        wrapper.attributedText = attributedText
        wrapper.delegate = context.coordinator
        return wrapper
    }
    
    func updateUIView(_ uiView: ConstrainedTextView, context: Context) {
        // Only update attributed text if it changed
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: SelectableTextView
        
        init(_ parent: SelectableTextView) {
            self.parent = parent
        }
        
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            // Handle link taps - open in Safari
            if interaction == .invokeDefaultAction {
                parent.safariURL = URL
                parent.showSafari = true
                return false // Don't use default handling
            }
            // Allow text selection for other interactions (like preview)
            return true
        }
    }
}


