# Zikr Adventure — iOS App Store build

A zikr counter ("Astaghfirullah") with a "Sira path": 7 levels, 19 chapters and isometric maps of 7th-century Mecca and Medina. Six UI languages: ru, en, uz, tg, kk, ky.

## Architecture

- **Native shell (Swift, SwiftUI + UIKit, iOS 16+).** `WKWebView` loads the bundled `Web/index.html` through a custom URL scheme (`zikr://localhost/`) served by `BundleSchemeHandler`. A stable origin keeps `localStorage` across launches.
- **Offline.** No network requests, no third-party SDKs, system fonts only. Navigation to any non-`zikr:` URL is cancelled.
- **Native bridge** (`window.webkit.messageHandlers.zikr`):
  - `{type:"haptic", style:"light|medium|success|warning"}` → `UIFeedbackGenerator`;
  - `{type:"keepAwake", on:Bool}` → `isIdleTimerDisabled`;
  - `{type:"save", data:String}` → `ProgressFileStore` writes `Application Support/progress.json`. This is a backup copy injected back as `window.__ZIKR_NATIVE_STATE` at document start.
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) declares no tracking and no collected data. `ITSAppUsesNonExemptEncryption = NO`.

## Build

1. Open `ZikrAdventure.xcodeproj` (Xcode 16 or later).
2. Target **ZikrAdventure** → Signing & Capabilities → select your Team and set your Bundle ID. The placeholder is `com.yourcompany.zikradventure`.
3. Run on a simulator or device. For release, choose **Product → Archive → Distribute App → App Store Connect**.

If the project file gives trouble, regenerate it with XcodeGen: `brew install xcodegen && xcodegen generate` (see `project.yml`).

CI without a Mac: `codemagic.yaml` (automatic signing via an App Store Connect API key).

## Status

- Prepared without access to a Mac. The Swift code has **not been compiled** and the project has **not been opened in Xcode**.
- The `.pbxproj` was machine-generated and structurally validated (parsed; all object references resolve).
- The web UI was exercised in headless Chromium: all tabs, both city maps, cards, language switching, reset and levels, with no JS errors.
- Please build once, run on a device, and report any compiler errors.

## Store materials

`AppStore/` contains:
- metadata in Russian and English;
- App Review notes;
- a privacy policy page (host it publicly and add a contact e-mail);
- 1320×2868 screenshots. These were rendered from the same page but with fallback fonts; re-capturing from an iPhone 16 Pro Max simulator is recommended.
