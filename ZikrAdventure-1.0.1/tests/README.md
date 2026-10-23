# Zikr Adventure Automated Tests

## Overview

This directory contains automated tests for the Zikr Adventure iOS app, written in Node.js using the built-in `vm`, `fs`, and `assert` modules. No external dependencies are required.

## Test Files

### `counters.cjs`
Tests the core counter functionality and bug fixes from version 1.0.1:
- Counter increments correctly (75 taps)
- Undo functionality works immediately
- Goal progress updates on each tap (fixed in 1.0.1)
- Native save messages sent with correct data (fixed in 1.0.1)
- Reset restoration prioritizes local state over stale native backups (fixed in 1.0.1)
- Inline JavaScript syntax validation

**Run:**
```bash
node tests/counters.cjs
```

**Expected output:** `PASS: original bugs reproduced; 75 taps, undo, immediate native save and reset restoration verified in 1.0.1. Full inline JavaScript syntax valid.`

### `auth.cjs`
Comprehensive tests for the account/authentication feature (version 1.1.0):

#### Localization Coverage
- Validates all 22 auth-specific strings are present in all 6 supported languages:
  - Russian (ru)
  - English (en)
  - Uzbek (uz)
  - Tajik (tg)
  - Kazakh (kk)
  - Kyrgyz (ky)
- Cross-references with design spec: `docs/auth/design/strings.json`

#### UI State Rendering
Tests that the account screen renders correctly for each auth state:
- **guest**: Shows Apple and Google sign-in buttons with intro text
- **signingIn**: Shows loading message with disabled buttons
- **signedIn**: Shows user name, email, provider badge, sign out and delete buttons
- **error**: Shows error message with retry buttons
- **offline**: Shows specific offline message (internet needed)
- **deleting**: Shows deleting message

#### Bridge Commands
Validates correct native bridge commands are sent:
- `auth.signInGoogle` - Google sign-in button
- `auth.signInApple` - Apple sign-in button  
- `auth.signOut` - Sign out button (with confirmation)
- `auth.deleteAccount` - Delete account button (with confirmation)

#### Event Handling
- Verifies `zikr:auth` event listener is registered
- Tests that auth state updates correctly from native events:
  - `signingIn` event
  - `signedIn` event with user data (uid, displayName, email, provider)
  - `error` event with message
  - `offline` error event
  - `deleting` event
  - `signedOut` / guest event

#### Regression Testing
- Counter works correctly with guest auth state (no account)
- Counter continues working when signed in
- Auth feature does not interfere with existing counter functionality
- Inline JavaScript syntax remains valid

**Run:**
```bash
node tests/auth.cjs
```

**Expected output:** `✅ PASS: All auth tests passed` with 15 individual test confirmations.

## Running All Tests

To run the complete test suite:

```bash
cd ZikrAdventure-1.0.1
node tests/counters.cjs && node tests/auth.cjs
```

Both tests must pass before any release.

## Test Architecture

These tests use a lightweight VM-based approach:
1. Extract the `<script>` content from `ZikrAdventure/Web/index.html`
2. Create a mock browser environment using Node's `vm.createContext()`
3. Mock DOM elements, localStorage, webkit messageHandlers, etc.
4. Execute portions of the actual app JavaScript in the mock environment
5. Assert expected behavior using Node's built-in `assert/strict` module

This approach:
- ✅ Tests the actual production code (no separate test implementation)
- ✅ Requires no external dependencies or frameworks
- ✅ Runs fast (< 200ms total)
- ✅ Works in any Node.js environment (local, CI/CD)
- ✅ Catches syntax errors, missing translations, state machine bugs, and regressions

## Coverage Summary

| Feature | Counter Tests | Auth Tests |
|---------|--------------|------------|
| Core counting | ✅ | ✅ (regression) |
| Undo | ✅ | - |
| Goal tracking | ✅ | - |
| Native save | ✅ | - |
| Reset/restore | ✅ | - |
| Auth UI states | - | ✅ (6 states) |
| Bridge commands | - | ✅ (4 commands) |
| Event handling | - | ✅ |
| Localization | - | ✅ (6 languages) |
| JS syntax | ✅ | ✅ |

## Future Tests

Consider adding:
- Map rendering and city interactions
- Chapter unlocking logic
- Settings persistence
- Onboarding flow
- History clearing and statistics
- Additional language validation
