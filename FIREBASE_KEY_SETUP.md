# Firebase key management for Beu

The app uses Firebase Anonymous Authentication + the Firestore REST API. No Firebase SDK package is required, so the existing Xcode project and unsigned GitHub Actions build remain simple.

## 1. Firebase project

The project ID is already set to `quan-li-beu` in `ThreeOneOSFive/Info.plist`.

In Firebase Console:

1. Enable **Authentication → Sign-in method → Anonymous**.
2. Open **Firestore Database** and create the database.
3. Deploy the rules from `firestore.rules`.
4. The provided `GoogleService-Info.plist` has been used to fill the Firebase Web API key in `ThreeOneOSFive/Info.plist`. The app uses the Firebase REST APIs directly, so the Firebase SDK is not required.

## 2. Firestore collection

Create a collection named `keys`.

The document ID is the key itself, for example:

`BEU-2026-002`

Recommended fields for a new key:

- `allowed` — Boolean: `true`
- `note` — String: optional, e.g. `test2`
- `deviceID` — leave absent/empty for a new key
- `authUID` — leave absent/empty for a new key
- `boundAt` — leave absent for a new key

The first device that activates an unbound key receives `deviceID`, `authUID`, and `boundAt`. Later activations on another installation are rejected.

## 3. Disable / reset a key

Set `allowed` to `false` to disable it.

To move a key to a new installation, clear `deviceID`, `authUID`, and `boundAt`, then set `allowed` back to `true`.

## 4. What was added to the app

- `helpers/FirebaseKeyService.swift` — Firebase anonymous auth, Firestore REST client, keychain storage, device binding.
- `views/LicenseGateView.swift` — key entry screen shown before the main app.
- `SettingsView.swift` — shows the active key and allows local key change.
- `App.swift` — gates the main UI behind successful key validation.
- `Info.plist` — Firebase project ID + API key configuration.
- `firestore.rules` — rules for reading/binding keys.
- English/Vietnamese localization strings.

The existing patch/file/exploit code is not changed by the key system.
