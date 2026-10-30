# SmartShopper

A family shopping app for iOS that turns a shared shopping list into a route of real nearby shops.
Built with **SwiftUI** and **MVVM**, with **Firebase** for real-time family sync, plus **MapKit**,
**Core Location geofencing**, **Core ML** and **Face ID**.

- **Module:** iOS Application Development (BSCCOMP25.1P)
- **Repository:** https://github.com/Dahara9lk/SmartShopper
- **Requirements:** Xcode 26.2 or newer, iOS 26.2 Simulator (iPhone 17 / iPad Pro), widget iOS 17.6+

---

## 1. Run the app (5 minutes)

1. Open **`SmartShopper.xcodeproj`** in Xcode.
2. Wait until Xcode finishes **Resolving packages** (Firebase is added with Swift Package Manager).
   If it doesn't start, use **File > Packages > Resolve Package Versions**.
3. Choose the **SmartShopper** scheme and an **iPhone 17** simulator.
4. Press **⇧⌘K** (clean), then **▶ Run**.
5. Press **⌘U** to run the unit tests.

### Test account

| Item | Value |
| --- | --- |
| Email | `[add test email]` |
| Password | `[add password]` |
| Family invite code | `[add invite code from Profile]` |

You can also create a new account from the **Create Account** screen.

### Simulator setup for the sensor features

| Feature | Setup |
| --- | --- |
| Location | **Features > Location > Custom Location…** → Colombo `6.9271`, `79.8612` |
| Face ID | **Features > Face ID > Enrolled**, then **Matching Face** (⌥⌘M) or **Non-matching Face** |
| Geofence alert | Profile → Shop Alert Radius **1.0 km** → Smart Map → **↻**. Move the location away (e.g. Kandy `7.2906`, `80.6337`) and back to Colombo; a "shop is nearby" notification appears |

---

## 2. Backend: Firebase

- **Firebase Authentication** (email and password)
- **Cloud Firestore** with real-time listeners and an offline cache
- Project: `smartshopper-6bc9b` (config file: `SmartShopper/GoogleService-Info.plist`)

**Data structure**

```
users/{uid}
households/{householdId}
    items/{itemId}
    trips/{tripId}
    activity/{eventId}
```

**Security rules** are in [`firestore.rules`](firestore.rules): a user can only read and write their own
profile, and only members of a household can read or write its items, trips and activity.
To publish them: Firebase console → Firestore Database → **Rules** → paste → **Publish**.

**Demo mode:** if `GoogleService-Info.plist` is missing, the app runs with on-device data
(`LocalAuthService`, `LocalDataService`), so every screen can still be tested.

---

## 3. Features and where they are in the code

| # | Feature | Main files | Apple SDK / service |
| --- | --- | --- | --- |
| 1 | Sign up, sign in, onboarding | `Views/Auth`, `AuthViewModel`, `Services/Auth` | Firebase Authentication |
| 2 | Profile, settings, Light / Dark / System theme | `Views/Profile`, `SettingsStore` | SwiftUI, colour assets |
| 3 | Home dashboard and offline state | `Views/Home`, `NetworkMonitor` | Network framework |
| 4 | Real-time family sync | `Services/Data/FirebaseDataService.swift` | Cloud Firestore |
| 5 | Notifications (store alerts, family updates, quiet hours) | `NotificationService` | UserNotifications |
| 6 | Face ID lock with passcode fallback | `SecurityViewModel`, `Services/Security`, `Views/Security` | LocalAuthentication, Keychain, CryptoKit |
| 7 | Shopping list and In-Store Mode | `Views/Lists`, `ListsViewModel`, `InStoreViewModel` | SwiftUI |
| 8 | Family list, invite code, QR code | `FamilyListView`, `ExportHelpers` | Firestore, Core Image |
| 9 | History, charts, CSV export | `Views/History`, `HistoryViewModel` | Swift Charts |
| A1 | **Smart Map: real shops, ranking, routes, geofencing** | `SmartMapViewModel`, `Services/Location`, `Views/SmartMap` | MapKit, Core Location, CLMonitor |
| A2 | **Item category classifier** | `Services/ML/ItemClassifierService.swift`, `Resources/ItemCategoryClassifier.mlmodel` | Core ML, Natural Language, Create ML |
| + | iPad layout | `App/MainTabView.swift` | NavigationSplitView, size classes |
| + | Home Screen and Lock Screen widgets | `SmartShopperWidget/`, `Services/WidgetBridge.swift`, `Services/WidgetShared.swift` | WidgetKit, App Groups |
| + | Siri and Shortcuts | `Intents/SmartShopperIntents.swift` | App Intents |
| + | Sri Lanka localisation (map opens on Colombo, prices in LKR) | `SmartMapViewModel` (`MapDefaults`), `Theme.swift` (`AppFormat`), `DemoData` | MapKit, Foundation |

### How Smart Map works

1. Each item on the list has a category (Dairy, Pharmacy, Electronics…), and each category maps to shop types.
2. **Core Location** gets the user's position.
3. **MKLocalSearch** finds real shops of the needed types within 5, 15 or 25 km.
4. **StoreMatcher** ranks them: `score = 0.7 × (items matched ÷ items remaining) + 0.3 × closeness`.
5. **MKDirections** draws the route. Apple Maps has no directions in Sri Lanka, so the app then shows
   the distance, an estimated time and a dashed line instead.
6. **CLMonitor** watches up to 10 of the best shops and sends a notification when the user enters
   a shop's radius (200 m to 2.5 km, set in Profile).

### How the item classifier works

- `ItemCategoryClassifier.mlmodel` is a **Text Classifier** trained in **Create ML** on
  `MLTraining/items_dataset.csv` (788 labelled items, 8 categories). The Create ML project is in `MLTraining/`.
- **Hybrid design:** item names containing a well-known word ("milk", "panadol") use keyword rules;
  other names ("breadfruit", "kimbula bun") are predicted by the Core ML model on the device.
- Profile shows **On-Device Item Classifier: Loaded** when the model is in the app.

| Model (Create ML) | Training | Validation | Test on 132 unseen items |
| --- | --- | --- | --- |
| Maximum Entropy, 50 iterations (used in the app) | 100% | 49% | 59% |
| Transfer Learning: BERT embedding, 20 iterations | 54% | 56% | not tested |

The unseen test set is `MLTraining/items_unseen_test.csv`.

**Retrain the model:** Xcode > Open Developer Tool > **Create ML** → Text Classification →
Training Data `items_dataset.csv` → Train → Output → **Get** → save as `ItemCategoryClassifier.mlmodel`
→ replace the file in `SmartShopper/Resources` (Target Membership: SmartShopper).

---

## 4. Architecture (MVVM)

```
SmartShopper/
  App/          entry point (@main), AppEnvironment (creates services once), RootView, MainTabView
  Models/       plain data: ShoppingItem, ShoppingTrip, Household, NearbyStore, ItemCategory ...
  ViewModels/   screen state and logic (@MainActor ObservableObject, @Published)
  Views/        SwiftUI screens grouped by tab + reusable Components
  Services/     Firebase / local backends (behind protocols), location, geofencing, MapKit search,
                Core ML, Face ID, Keychain, notifications, widget bridge
  Intents/      App Intents (Siri / Shortcuts)
  Theme/        colour tokens (light and dark) and formatting
  Resources/    Assets.xcassets, ItemCategoryClassifier.mlmodel
SmartShopperTests/    Swift Testing unit tests
SmartShopperWidget/   WidgetKit extension
MLTraining/           Create ML dataset, unseen test set and Create ML project
firestore.rules       Firestore security rules
```

- Views only show data; ViewModels hold the state; Services do the work.
- `AuthServiceProtocol` and `DataServiceProtocol` each have a Firebase and a local version.
  `AppEnvironment` picks one at launch and injects it (dependency injection), so the same app runs
  on Firebase, in demo mode and inside unit tests.
- All prices go through `AppFormat.money`, so the currency (LKR) is set in one place.

---

## 5. Testing

**61 unit tests** with Swift Testing (`@Test`, `#expect`, parameterised `arguments:`). Run with **⌘U**.

| Test file | What it checks |
| --- | --- |
| `ListAndHistoryTests` | Filters, progress, totals, aisle order, In-Store Mode, history statistics, CSV export |
| `DataStoreTests` | Accounts, invite codes, quick add, trips, sign-out, settings |
| `SecurityTests` | Passcode lockout (60 s, then 5 min), SHA-256 hashing, Keychain, quiet hours |
| `ValidatorTests` | Email, name, password strength, invite code and passcode rules |
| `MachineLearningTests` | Item categories, keyword rules, confidence, category-to-shop mapping |
| `StoreMatcherTests` | Shop types needed, matching, scoring and ranking |
| `WidgetTests` | Widget item count, next items, best shop |

Tests use the local services, so they run without internet.

---

## 6. Accessibility

- VoiceOver labels and hints on rows, cards, map pins, buttons and the passcode keypad
- Dynamic Type through system text styles
- Reduce Motion support for button animations
- Light and dark colour values for every colour; status never shown by colour alone
- Touch targets of at least 44 pt
- Passcode alternative to Face ID

Checked with Xcode's **Accessibility Inspector** and the largest text size in the Simulator.

---

## 7. Known limitations

- **Widget live data** needs an App Group (`group.lk.nibm.smartshopper`) on both the app and widget
  targets, which requires a signed development team. Without it the widget shows its empty state.
- **Directions:** Apple Maps has no routing in Sri Lanka; the app shows distance and an estimate instead.
- **Notifications** are local (geofence and Firestore listener). Remote push and Sign in with Apple
  need a paid Apple Developer account.
- **Core ML accuracy** is limited by the small dataset (59% on unseen items); keyword rules cover common items.
- Tested in the Xcode Simulator (location and Face ID simulated).
