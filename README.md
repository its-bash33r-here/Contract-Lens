# ClauseGuard

> **TerraCode Convergence 2026 Hackathon Project**

**ClauseGuard** is an AI-powered iOS app that scans any contract in seconds and flags dangerous clauses — before you sign something you'll regret.

Paste text, snap a photo, or upload a PDF. ClauseGuard returns a **Safety Score**, plain-English explanations for every red flag, and suggested fixes — powered by Google Gemini 2.0 Flash.

---

## Features

- **Contract Scanner** — Paste text, photograph a document, or import a PDF
- **Safety Score (0–100)** — Instant risk rating with a visual arc gauge
- **Flag Cards** — Every risky clause quoted, explained, and accompanied by a suggested fix
- **Legal Chat** — Ask follow-up questions about any clause in plain English
- **Voice Input** — Dictate questions hands-free
- **Export** — Share full analysis as PDF or plain text
- **Conversation History** — All past analyses saved locally via Core Data

---

## Tech Stack

| Layer | Technology |
|---|---|
| Platform | iOS 16.6+ / iPadOS 16.6+, SwiftUI |
| Architecture | MVVM + Core Data |
| AI | Google Gemini 2.0 Flash (contract analysis, JSON mode) |
| AI — Chat/OCR | Google Gemini 2.5 Flash |
| Document OCR | Apple Vision framework (on-device) |
| PDF parsing | PDFKit |
| Voice | AVFoundation / SFSpeechRecognizer |

---

## Getting Started

### Prerequisites

- Xcode 15.4+
- iOS 16.6+ device or simulator
- A [Google AI Studio](https://aistudio.google.com) API key (free tier works)

### Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/its-bash33r-here/Contract-Lens.git
   cd Contract-Lens
   ```

2. Add your Gemini API key:
   ```bash
   cp lawgpt/Secrets.swift.template lawgpt/Secrets.swift
   # Edit lawgpt/Secrets.swift and replace YOUR_GEMINI_API_KEY_HERE
   ```

3. Add `Secrets.swift` to the Xcode project:
   - Right-click the `lawgpt` group in the Project Navigator
   - **Add Files to "lawgpt"** → select `Secrets.swift` → Add

4. Open the project:
   ```bash
   open lawgpt.xcodeproj
   ```

5. Select your development team under **Signing & Capabilities**, then build and run.

> `Secrets.swift` is gitignored — your API key will never be committed.

---

## Project Structure

```
lawgpt/
├── Models/
│   ├── ContractAnalysisResult.swift   # Codable result + clause models
│   └── ConversationThread.swift       # Core Data chat model
├── ViewModels/
│   ├── ContractScannerViewModel.swift # Scanner state machine
│   └── ChatViewModel.swift            # Legal chat logic
├── Views/
│   ├── ContractScannerView.swift      # Full scanner flow (input → results)
│   ├── SafetyGaugeView.swift          # Arc-based score gauge
│   ├── FlagCardView.swift             # Expandable clause cards
│   └── ActiveChatView.swift           # Legal chat interface
├── Services/
│   ├── GeminiService.swift            # Gemini REST client (chat + analysis)
│   └── ExportService.swift            # PDF / text export
└── Secrets.swift.template             # API key template (copy → Secrets.swift)
```

---

## How It Works

1. User inputs a contract (text / camera / PDF)
2. PDF text is extracted via PDFKit; images are OCR'd via Vision
3. Text is truncated to 25k chars and sent to `gemini-2.0-flash` with a structured JSON schema prompt
4. Gemini returns `{ safety_score, summary, analysis[] }` — each clause has `type`, `title`, `quote`, `explanation`, `fix`
5. Results are decoded into `ContractAnalysisResult` and rendered as a Safety Gauge + Flag Cards

---

## Permissions

| Permission | Reason |
|---|---|
| Camera | Photograph physical contracts |
| Photo Library | Select contract images from gallery |
| Microphone | Voice input for legal questions |
| Speech Recognition | Convert voice to text |

---

## License

MIT — see [LICENSE](LICENSE)

---

## Disclaimer

ClauseGuard provides general legal information only. It does not constitute legal advice and does not create an attorney-client relationship. Always consult a licensed attorney before signing any agreement.
