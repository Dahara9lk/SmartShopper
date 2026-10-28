# SmartShopper (iOS, SwiftUI, MVVM)

A shopping assistant for individuals and families: smart shopping lists, real-time family lists,
on-device Core ML item categories, and a Smart Map that finds real shops that have your items
and alerts you (geofencing) when you pass one.

NIBM / Coventry - iOS Application Development (BSCCOMP25.1P) - Final coursework.

---

## 1. Open and run (5 minutes)

1. Unzip, then double-click **`SmartShopper.xcodeproj`** (Xcode 16 or newer; built for Xcode 26 / iPhone 17 Simulator).
2. Xcode downloads the Firebase package automatically (File > Packages > Resolve Package Versions if it doesn't).
   This needs internet the first time and can take a few minutes.
3. Select the **SmartShopper** target > *Signing & Capabilities* > choose your **Team** (your free Apple ID is fine).
   If Xcode says the bundle ID is taken, change `com.smartshopper.student.SmartShopper` to something unique.
4. Pick **iPhone 17** in the device menu and press **Run (⌘R)**.

The app runs straight away in **Demo mode** (accounts and lists saved on the device only) -
even before the Firebase package is added. Add Firebase (next step) to switch to the real cloud backend; no code changes needed.

## 2. Connect Firebase (the external backend for Component 2)

1. https://console.firebase.google.com > **Add project** > "SmartShopper".
2. **Add app > iOS**. Bundle ID = the bundle ID from step 1.3. Download **GoogleService-Info.plist**.
3. Drag `GoogleService-Info.plist` into the **SmartShopper** folder in Xcode (tick "Copy items if needed" and the SmartShopper target).
4. Firebase console > **Authentication > Sign-in method > Email/Password > Enable**.
5. Firebase console > **Firestore Database > Create database** (production mode, a nearby region).
6. Firestore > **Rules** > paste the contents of `firestore.rules` > **Publish**.
7. Run the app again. The Profile screen footer now says **"Firebase connected"**.

Database layout:

| Path | What |
|---|---|
| `users/{uid}` | profile (name, email, householdId) |
| `households/{id}` | family circle: name, inviteCode, members, memberIds |
| `households/{id}/items/{itemId}` | shopping items (my list + family list) |
| `households/{id}/trips/{tripId}` | finished shopping trips (History) |
| `households/{id}/activity/{eventId}` | "Mom added Oat Milk" feed |

**For the markers:** create a demo account in the app, then in Firebase console > *Project settings > Users and permissions*
add the lecturer's email as **Viewer**. Put the demo email/password in the report.

## 3. Features and where they are in the code

| # | Feature (proposal) | Files | Apple SDK / service |
|---|---|---|---|
| 1 | Auth & onboarding (S22, S1, S26) | `Views/Auth/*`, `ViewModels/AuthViewModel.swift`, `Services/Auth/*` | Firebase Authentication |
| 2 | Profile & settings, **Light / Dark / System theme** (S23) | `Views/Profile/ProfileView.swift`, `Services/SettingsStore.swift` | SwiftUI `preferredColorScheme`, colour sets |
| 3 | Dashboard (S11) + offline state (S21) | `Views/Home/*` | Network framework |
| 4 | Firebase backend, real-time sync | `Services/Data/FirebaseDataService.swift` | Cloud Firestore listeners + offline cache |
| 5 | **Push notifications** (MVP pick) (S13, S19, S20) | `Services/NotificationService.swift`, `Views/Profile/NotificationSettingsView.swift` | UserNotifications |
| 6 | **Face ID** (MVP pick) (S9, S7, S24, S8) | `ViewModels/SecurityViewModel.swift`, `Services/Security/*`, `Views/Security/LockViews.swift` | LocalAuthentication, Keychain, CryptoKit |
| 7 | Shopping list (S3, S5, S6) + In-Store Mode (S12) | `Views/Lists/*`, `ViewModels/ListsViewModel.swift`, `InStoreViewModel.swift` | |
| 8 | Family list (S10, S16) | `Views/Lists/FamilyListView.swift` | Firestore, ShareLink, Core Image QR |
| 9 | History & statistics (S2, S18, S28) | `Views/History/*`, `ViewModels/HistoryViewModel.swift` | Swift Charts |
| A1 | **MapKit + Core Location + geofencing** (S27, S15, S17, S14, S25, S4) | `ViewModels/SmartMapViewModel.swift`, `Services/Location/*`, `Views/SmartMap/*` | MapKit, MKLocalSearch, MKDirections, CLMonitor |
| A2 | **Core ML item classifier** | `Services/ML/ItemClassifierService.swift`, `Resources/ItemCategoryClassifier.mlmodel` (you train it - see below), `MLTraining/items_dataset.csv` | Core ML + Natural Language (on-device), Create ML |
| + | Siri / Shortcuts | `Intents/SmartShopperIntents.swift` | App Intents |
| + | iPad layout | `App/MainTabView.swift` (NavigationSplitView), two-column Home, side panel on Smart Map | Size classes |
| + | **Home Screen + Lock Screen widgets** (small, medium, rectangular, circular, inline; StandBy) | `SmartShopperWidget/*`, `Services/WidgetShared.swift` (in both targets), `Services/WidgetBridge.swift` | WidgetKit, App Groups |

### How the advanced features work together
1. When an item is added, **Core ML** predicts its shop category on the phone (e.g. "USB-C cable" -> Electronics).
2. **Smart Map** turns the categories still to buy into shop types (supermarket, bakery, pharmacy, electronics).
3. **MKLocalSearch** finds real shops of those types around the user (**Core Location**).
4. `StoreMatcher` ranks shops by how many remaining items they cover (70%) and distance (30%).
5. **MKDirections** draws the route, the ETA and the detour minutes (set a destination with "Change Route").
6. **CLMonitor geofences** are added around the 10 best shops. Entering one sends a notification
   listing the items that shop has, with *Snooze 10m* and *Shop & Route* buttons.

### The Core ML model (train it yourself in Create ML - 2 minutes)
1. In Xcode: menu **Xcode > Open Developer Tool > Create ML**.
2. **New Document > Text Classification** > Next > name it `ItemCategoryClassifier` > save it anywhere.
3. **Training Data**: click + and choose `MLTraining/items_dataset.csv` (788 labelled items, columns `text` and `label`).
   Leave Validation and Testing on *Automatic*. Algorithm: **Maximum Entropy** (or Transfer Learning for better accuracy).
4. Click **Train** (top left). Check the Training / Validation accuracy numbers - put them in your report.
5. Open the **Output** tab, try a few items (e.g. "oat milk", "usb charger"), then click **Get** and save
   `ItemCategoryClassifier.mlmodel`.
6. Drag `ItemCategoryClassifier.mlmodel` into Xcode's **Resources** folder (tick the SmartShopper target).
7. Run the app. Profile > Preferences shows "On-Device Item Classifier: Loaded".

Until the model is added, `KeywordClassifier` (same file) is used so the app still works.

### Accessibility checklist (Component 4)
- **VoiceOver**: about 100 `accessibilityLabel` / `accessibilityHint` / `accessibilityElement(children: .combine)`
  modifiers, so rows, cards, map pins, the keypad and the widgets read as one clear sentence.
- **Dynamic Type**: only system text styles (`.headline`, `.caption`...) are used, so all text grows with the
  user's text size; long text wraps instead of being cut off.
- **Reduce Motion**: the button press animation (`PressableStyle`) is turned off when Reduce Motion is on.
- **Colour**: every colour has a light and a dark value; status is never shown by colour alone
  (always an icon or text too, e.g. "Not Set", "0% match").
- **Touch targets**: buttons are at least 44-52 pt high.
- **Face ID fallback**: a 6-digit passcode for people who can't use Face ID.

## 4. Testing in the Simulator

Run all unit tests: **⌘U** (Swift Testing, in `SmartShopperTests/`).

| Feature | How to test |
|---|---|
| Face ID | *Features > Face ID > Enrolled*. Turn on Face ID in Profile. Lock: background the app (⇧⌘H) and reopen. *Features > Face ID > Matching Face* unlocks, *Non-matching Face* shows the passcode keypad. 3 wrong passcodes = 60 s lockout. |
| Location | *Features > Location > Custom Location...* e.g. Colombo 6.9271, 79.8612 (or Apple's default). |
| Smart Map | Add a few items (milk, bread, panadol, usb cable), open Smart Map, allow location. |
| Geofence alert | After Smart Map finds shops, set *Custom Location* to the coordinates of one of the shops (or use *Freeway Drive*). A notification appears. |
| Notifications | Profile > All Notification Settings > **Send Test Commute Notification** - lock the simulator (⌘L) to see it on the lock screen. |
| Family sync | Run on two simulators (iPhone 17 + iPad), create an account on one, join with the **invite code** on the other. |
| Offline | Turn the Mac's Wi-Fi off: Home shows the offline panel; changes sync when back online (Firebase mode). |
| Dark mode | Profile > Appearance > Dark (or *Features > Toggle Appearance* ⇧⌘A). |
| Dynamic Type / VoiceOver | Xcode debug bar > Environment Overrides; Accessibility Inspector (Xcode > Open Developer Tool). |
| Siri / Shortcuts | Run once, then open the Shortcuts app > SmartShopper. |
| Widgets | Go to the Home Screen, long-press empty space > **Edit > Add Widget** > SmartShopper. Lock Screen: ⌘L, long-press the lock screen > Customize. Add or tick an item in the app and the widget updates. |
| Apple Maps directions | Apple Maps has no driving directions in Sri Lanka. Smart Map then shows the distance, an estimated time and a dashed line. To demo real turn-by-turn, set *Features > Location > Apple*. |

## 5. Architecture (MVVM)

```
SmartShopper/
  App/          entry point (@main), AppEnvironment (creates services once), RootView, MainTabView
  Models/       plain data: ShoppingItem, ShoppingTrip, Household, NearbyStore, ItemCategory ...
  ViewModels/   screen logic + shared state (AppDataStore, SecurityViewModel, SmartMapViewModel ...)
  Views/        SwiftUI screens grouped by tab + reusable Components
  Services/     Firebase / demo backends (behind protocols), Face ID, Keychain, notifications,
                location, geofencing, MapKit search, Core ML, CSV export
  Intents/      App Intents (Siri / Shortcuts)
  Theme/        colour tokens (every colour has a light AND a dark value in Assets.xcassets)
  Resources/    Assets.xcassets, ItemCategoryClassifier.mlmodel
SmartShopperWidget/  WidgetKit extension (Home Screen + Lock Screen widgets)
SmartShopperTests/   Swift Testing unit tests
MLTraining/          dataset + training script for the Core ML model
```

- Views never talk to Firebase directly: they call view models, which use services through
  `AuthServiceProtocol` / `DataServiceProtocol`. That is why the same app runs on Firebase, in demo mode,
  and inside unit tests (dependency injection).
- `@MainActor` view models update the UI; services do the async work.

## 6. Honest notes for the report

- **Sign in with Apple** and **remote APNs push** need a paid Apple Developer account, so the Apple buttons
  show an explanation and notifications are local (triggered by geofences and the Firestore listener).
- **Turn-by-turn**: the route line, steps, distance and ETA are real MKDirections data; full voice navigation
  hands off to Apple Maps ("Open in Apple Maps").
- **In-store aisles** come from the item category (Produce = aisle 1 ...), not indoor positioning.
- Opening hours, ratings and photos of shops are not available from MKLocalSearch, so they are not shown.
- The brief asks for a **declaration of LLM / AI use** in the final report - list what AI helped with.
