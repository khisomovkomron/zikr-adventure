# SwiftUI Foundation Migration - Architecture

## Overview

This foundation implements a native SwiftUI tab navigation structure while maintaining full compatibility with the existing WKWebView-based application. All features (counter, history, haptic feedback, persistence, sign-in) remain fully functional during the migration.

## Architecture

### File Structure

```
ZikrAdventure/
├── App/
│   ├── ZikrAdventureApp.swift       # Entry point - now uses TabsView
│   ├── TabsView.swift               # Native SwiftUI tab navigation
│   ├── TabItem.swift                # Tab definitions (titles, icons, web sections)
│   ├── WebContentView.swift         # SwiftUI wrapper for web sections
│   ├── WebAppViewController.swift   # WKWebView controller (enhanced)
│   ├── BundleSchemeHandler.swift    # Web resource handler
│   └── ProgressFileStore.swift      # Progress persistence
├── Localizable.xcstrings            # String Catalog (6 languages)
├── Resources/
└── Web/
    └── index.html                   # Existing web application
```

### Navigation Flow

1. **ZikrAdventureApp** launches **TabsView**
2. **TabsView** creates a native TabView with 5 tabs:
   - Зикр (Zikr) - hand.tap.fill
   - Карта (Map) - map.fill
   - Путь Сиры (Path of Sira) - book.fill
   - Инфо (Info) - info.circle.fill
   - Настройки (Settings) - gearshape.fill

3. Each tab currently displays **WebContentView**
4. **WebContentView** wraps **WebAppViewController** and passes the section ID
5. **WebAppViewController** loads the web app and switches to the requested section

### Web Section Switching

The `WebAppViewController.showSection()` method uses JavaScript to:
- Show/hide the appropriate `.screen` element
- Update tab `aria-selected` attributes
- Preserve all web app functionality (counter, persistence, bridges)

This allows the native tab bar to control which web section is visible.

### Localization

- **Localizable.xcstrings**: String Catalog with tab titles in 6 languages (ru, en, uz, tg, kk, ky)
- Follows the app's language selection
- Matches the existing web app localization keys

### Future Migration Path

Future tasks will replace web sections with native views one at a time:

```swift
// In TabsView.contentView(for:)
switch tab {
case .settings: NativeSettingsView()  // ZKR-50
case .info: NativeInfoView()          // ZKR-48
case .zikr: NativeZikrView()          // ZKR-52
case .path: NativePathView()          // ZKR-53
case .map: NativeMapView()            // ZKR-57
}
```

Each native view can share the existing:
- `ProgressFileStore` for persistence
- Haptic feedback generators
- Keep-awake functionality
- Localization system

## Key Design Decisions

### 1. Shared WKWebView Instances
Each tab has its own WebContentView wrapping a WebAppViewController. This ensures:
- Independent web view state per tab
- No flickering when switching tabs
- Proper memory management

### 2. Web Section Control
JavaScript-based section switching instead of multiple HTML pages:
- Preserves localStorage state
- Maintains all existing bridges and functionality
- Seamless transition between tabs

### 3. String Catalog
Using `.xcstrings` (Xcode 15+) instead of `.lproj` files:
- Modern Apple localization format
- Better merge conflict resolution
- Xcode's built-in localization tools
- Easy to add new strings

### 4. Minimal Changes to Web App
The web application (`index.html`) requires no changes:
- All sections remain functional
- Native tab bar replaces the web tab bar
- Web tab bar is hidden (can be done via CSS or by removing the tabbar element if needed)

## Testing Notes

This implementation should be tested on:
- iPhone SE (smallest screen)
- iPhone 15 Pro Max (largest screen)
- All 6 language settings
- Dark mode and light mode
- Switching between tabs rapidly
- Memory usage with all tabs loaded

## Compatibility

- iOS 16.0+ (matches existing deployment target)
- iPhone only (TARGETED_DEVICE_FAMILY = 1)
- Portrait orientation only
- No changes to bundle identifier or version numbers
- All existing bridges (haptic, keepAwake, save) work unchanged

## Known Considerations

1. **Memory**: Each tab creates a WKWebView instance. iOS manages memory well, but if memory pressure occurs, inactive web views may be terminated and reloaded.

2. **State Preservation**: Each tab's web state is preserved in its WebView's localStorage and in the shared ProgressFileStore.

3. **Animation**: Tab switching shows a native fade transition instead of the web app's animations.

4. **Build**: The Xcode project has been updated to include the new files. If using XcodeGen, run `xcodegen generate` to regenerate from `project.yml`.
