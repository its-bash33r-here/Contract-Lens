# LawGPT

LawGPT is an iOS/iPadOS app that provides accurate legal information from trusted sources using AI.

## Features

- 💬 Chat-based legal information queries
- 🎤 Voice input support
- 📷 Image analysis for legal documents and contracts
- 📱 Support for iPhone and iPad

## Requirements

- iOS 16.6+
- iPadOS 16.6+
- Xcode 15.0+
- Swift 5.0+

## Building the App

1. Clone the repository:
   ```bash
   git clone https://github.com/its-bash33r-here/lawgpt.git
   cd lawgpt
   ```

2. Open the project in Xcode:
   ```bash
   open lawgpt.xcodeproj
   ```

3. Select your development team in the project settings.

4. Build and run on your device or simulator.

## TestFlight Deployment

### Prerequisites

Before deploying to TestFlight, ensure you have:

1. **Apple Developer Account** - An active Apple Developer Program membership ($99/year)
2. **App Store Connect Access** - Your app registered in App Store Connect
3. **App Icon** - A 1024x1024 app icon (required for App Store)
4. **Bundle Identifier** - Currently set to `com.kb.lawgpt` (update in Xcode project settings)

### Option 1: Deploy Using Xcode (Manual)

1. **Open the project** in Xcode
2. **Select your team** in Signing & Capabilities
3. **Set version and build number** in General settings
4. **Archive the app**:
   - Select "Any iOS Device" as the build destination
   - Go to Product → Archive
5. **Distribute via App Store Connect**:
   - In the Organizer, select your archive
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Follow the prompts to upload

### Option 2: Deploy Using GitHub Actions (Automated)

This repository includes a GitHub Actions workflow for automated TestFlight deployment.

#### Setting Up GitHub Secrets

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Description |
|-------------|-------------|
| `P12_CERTIFICATE_BASE64` | Base64-encoded distribution certificate (.p12) |
| `P12_PASSWORD` | Password for the .p12 certificate |
| `PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store provisioning profile |
| `KEYCHAIN_PASSWORD` | A temporary password for the build keychain |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID (e.g., `58PGB8ZUDS`) |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded API key file (.p8) |

#### How to Get These Values

1. **P12 Certificate**:
   - Open Keychain Access
   - Export your "Apple Distribution" certificate as .p12
   - Encode: `base64 -i certificate.p12 | pbcopy`

2. **Provisioning Profile**:
   - Download from Apple Developer Portal
   - Encode: `base64 -i profile.mobileprovision | pbcopy`

3. **App Store Connect API Key**:
   - Go to App Store Connect → Users and Access → Keys
   - Generate a new API key with "App Manager" role
   - Download the .p8 file
   - Encode: `base64 -i AuthKey_XXXXXX.p8 | pbcopy`

#### Triggering a Deployment

- **Automatic**: Push to `main` branch or create a tag starting with `v`
- **Manual**: Go to Actions → "Deploy to TestFlight" → Run workflow

### App Store Connect Setup

Before your first TestFlight upload:

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Create a new app with bundle ID `com.kb.lawgpt`
3. Fill in the required metadata:
   - App Name: LawGPT
   - Primary Language: English
   - Bundle ID: com.kb.lawgpt
   - SKU: A unique identifier (e.g., LAWGPT001)
4. Add screenshots (required for TestFlight):
   - 6.7" (iPhone 14 Pro Max)
   - 6.5" (iPhone 14 Plus)
   - 5.5" (iPhone 8 Plus)
   - 12.9" iPad Pro
5. Add privacy policy URL (required)

### TestFlight Testing

After successful upload:

1. Wait for Apple to process the build (usually 15-30 minutes)
2. Go to App Store Connect → TestFlight
3. Add internal testers (up to 100)
4. Submit for external testing review if needed (up to 10,000 testers)

## App Icon

The project includes an app icon slot but requires a 1024x1024 icon image. To add your icon:

1. Create a 1024x1024 PNG image
2. Open `Assets.xcassets` in Xcode
3. Drag your icon to the `AppIcon` asset

## Privacy & Permissions

The app requests the following permissions:

- **Camera**: To capture and analyze legal documents and contracts
- **Microphone**: For voice input
- **Photo Library**: To analyze legal documents
- **Speech Recognition**: To convert voice to text

## License

[Add your license here]

## Support

[Add support contact information here]
