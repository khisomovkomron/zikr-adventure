# SwiftUI Foundation Migration - Architecture (v1.1.1)

## Overview

This foundation implements a native SwiftUI tab navigation structure while maintaining full compatibility with the existing WKWebView-based application. All features (counter, history, haptic feedback, persistence, sign-in, Firebase, account deletion) remain fully functional during the migration.

## Critical Design: Single Shared WKWebView

**Problem Solved**: Multiple WKWebView instances cause:
- Multiple AuthCoordinator instances → auth handlers registered 5 times
- Divergent state → counts go stale between tabs, settings overwrite each other
- Memory overhead → 5 separate WebViews with identical content

**Solution**: ONE shared WKWebView managed by `WebViewManager.shared`:
- Created once at app launch
- Reused across all web-backed tabs
- Single AuthCoordinator instance
- Consistent state across all tabs
- Native tab bar calls web's `selectTab(id)` function

## Architecture

### File Structure

```
ZikrAdventure/
├── App/
│   ├── ZikrAdventureApp.swift       # Entry point - launches TabsView
│   ├── TabsView.swift               # Native SwiftUI tab navigation
│   ├── TabItem.swift                # Tab definitions (titles, icons, web IDs)
│   ├── WebContentView.swift         # SwiftUI wrapper (reuses shared WebView)
│   ├── WebViewManager.swift         # Singleton managing the shared WebView
│   ├── AppLanguage.swift            # Observable language state from web
│   ├── WebAppViewController.swift   # WKWebView controller (enhanced)
│   ├── AuthCoordinator.swift        # Firebase auth (unchanged)
│   ├── BundleSchemeHandler.swift    # Web resource handler (unchanged)
│   └── ProgressFileStore.swift      # Progress persistence (unchanged)
└── Web/
    └── index.html                   # Web app with native integration
```

### Navigation Flow

1. **ZikrAdventureApp** launches **TabsView**
2. **TabsView** creates native TabView with 5 tabs (Зикр, Карта, Путь Сиры, Инфо, Настройки)
3. Each tab shows **WebContentView**
4. **WebContentView** accesses **WebViewManager.shared** to get the single WebAppViewController
5. On tab switch, **WebContentView.updateUIViewController** calls `WebViewManager.selectTab(tabID)`
6. **WebViewManager** calls `WebAppViewController.selectTab(tabID)`
7. **WebAppViewController** executes JavaScript: `selectTab('zikr')` / `selectTab('map')` etc.
8. Web app's `selectTab()` function properly switches screens, renders content, updates state

### Web Integration

#### 1. Hiding Web Tab Bar

JavaScript injected at document start:
```javascript
window.__ZIKR_NATIVE_TABS = true;
document.addEventListener('DOMContentLoaded', () => {
    const tabbar = document.getElementById('tabbar');
    if (tabbar) tabbar.style.display = 'none';
});
```

The web tab bar is hidden but remains in the DOM (preserving all event listeners and logic).

#### 2. Language Synchronization

**Problem**: Native tab titles use iOS system language, not the in-app language setting.

**Solution**: Web posts language changes to native:

```javascript
// On language change or page load
post({ type: "lang.change", lang: "ru", tabs: { 
    zikr: "Зикр", 
    map: "Карта", 
    path: "Путь Сиры", 
    info: "Инфо", 
    settings: "Настройки" 
}});
```

Native handler updates `AppLanguage`:
- `@Published var currentLang: String`
- `@Published var tabTitles: [String: String]`
- Persisted in UserDefaults for correct first frame after relaunch

#### 3. Calling Web's selectTab()

Native calls the web's own navigation function:
```javascript
if (typeof selectTab === 'function') selectTab('map');
```

This ensures:
- Proper screen switching (`.screen` visibility)
- Correct rendering (`renderMap()`, `renderZikr()`, etc.)
- State updates and cleanup
- Wake lock management
- Tab bar state (aria-selected)

## Localization

Tab titles dynamically update from the web app in the user's chosen language:
- Initial load: web sends `lang.change` on DOMContentLoaded
- Language change: web sends `lang.change` when user selects a language
- Native persists: language and tab titles saved to UserDefaults
- First frame correct: tab titles loaded from UserDefaults before web finishes loading

Supported languages: ru, en, uz, tg, kk, ky

## Safe Area & Layout

- `.ignoresSafeArea()` applied to WebContentView to allow web content to extend edge-to-edge
- Web content handles its own padding via CSS env(safe-area-inset-*)
- No white strip under status bar
- Tab bar respects safe area automatically (iOS system behavior)

## Future Migration Path

Replace web sections with native views one at a time:

```swift
// In TabsView.contentView(for:)
switch tab {
case .settings: NativeSettingsView()  // ZKR-50
case .info: NativeInfoView()          // ZKR-48
case .zikr: NativeZikrView()          // ZKR-52
case .path: NativePathView()          // ZKR-53
case .map: NativeMapView()            // ZKR-57
default: WebContentView(tab: tab)     // Fallback
}
```

Each native view can access:
- `ProgressFileStore` for persistence
- `AppLanguage` for localization
- Haptic feedback generators
- Keep-awake functionality (UIApplication.shared.isIdleTimerDisabled)

## Key Design Decisions

### 1. Single WKWebView via Singleton

**Why**: Prevents multiple AuthCoordinators, state divergence, memory waste.  
**How**: `WebViewManager.shared` creates WebAppViewController once, all tabs reuse it.  
**Benefit**: One auth coordinator, consistent state, proper sign-in/cloud sync.

### 2. JavaScript-based Section Switching

**Why**: Preserves all web app logic, state, and event listeners.  
**How**: Native calls web's `selectTab(id)` function.  
**Benefit**: No duplication of navigation logic, proper render functions called.

### 3. Web-to-Native Language Push

**Why**: Native tab titles must reflect in-app language, not iOS system language.  
**How**: Web posts `lang.change` message with current language and tab titles.  
**Benefit**: Correct localization from first frame, persisted across relaunches.

### 4. Hidden Web Tab Bar

**Why**: Native tab bar replaces web tab bar, but web tab bar can't be removed (breaks logic).  
**How**: `display: none` via injected JavaScript, only when `__ZIKR_NATIVE_TABS` is set.  
**Benefit**: Web code unchanged, tab bar hidden cleanly in native mode.

## Compatibility

✅ **All existing functionality preserved:**
- Zikr counter works
- Daily history saved
- Haptic feedback active
- Progress persistence functional
- Firebase auth functional
- Google/Apple sign-in works
- Account deletion works
- Cloud sync functional
- 6-language localization
- All settings accessible
- Sira path and maps work

✅ **Project settings unchanged:**
- iOS 16.0+ deployment target
- iPhone only (TARGETED_DEVICE_FAMILY = 1)
- Portrait orientation only
- Bundle identifier: `com.komronkhisomov.zikradventure`
- MARKETING_VERSION: 1.1.1 (unchanged)
- CURRENT_PROJECT_VERSION: 3 (unchanged)
- Firebase packages preserved
- GoogleSignIn package preserved
- Entitlements preserved (Sign in with Apple)

## Testing Notes

Test on:
- iPhone SE (smallest screen)
- iPhone 15 Pro Max (largest screen)
- All 6 language settings (ru, en, uz, tg, kk, ky)
- Dark mode and light mode
- Tab switching (verify no blank screens)
- Counter increments correctly across tab switches
- Language change reflects in native tabs
- Sign in with Google
- Sign in with Apple
- Account deletion
- Cloud sync after sign-in
- Settings persist across tab switches
- No white strip under status bar

## Known Limitations

None - all blockers addressed:
1. ✅ Wrong project - fixed (working in ZikrAdventure-1.0.1)
2. ✅ Blank tabs - fixed (calls web's selectTab())
3. ✅ State divergence - fixed (single shared WebView)
4. ✅ Doubled tab bar - fixed (web tab bar hidden)
5. ✅ Language follows iOS - fixed (web posts lang.change)
6. ✅ White strip - fixed (.ignoresSafeArea() added)
