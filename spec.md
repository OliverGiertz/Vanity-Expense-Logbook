# Vanity Expense Logbook – Projektspezifikation

> Stand: 2026-06-12 · Version 3.0.1 · Branch `main`

---

## 1. App-Identität

| Eigenschaft | Wert |
|---|---|
| App-Name | Vanity Expense Logbook |
| Bundle ID | `VanityOnTour.CamperLogBook` |
| Display Name | Vanity Expense Logbook |
| Kategorie | `public.app-category.travel` |
| Development Region | `de` |
| Verschlüsselung | Nein (`ITSAppUsesNonExemptEncryption: false`) |

---

## 2. Versionsstand

| Feld | Wert |
|---|---|
| Marketing Version | `3.0.1` |
| Build Number | `26.3.01` |
| Letzter Commit | `837fc3f` – fix(build): resolve Sendable warnings and deprecated MapKit API |

**Build-Nummern-Schema:** `JJ.Major.MinorPatch`
- `JJ` = letzte zwei Ziffern des Jahres (26 → 2026)
- `Major` = Hauptversionsnummer
- `MinorPatch` = Minor + Patch zusammengeschrieben (v3.0.1 → 26.3.01)

---

## 3. Plattform & Deployment

| Eigenschaft | Wert |
|---|---|
| Minimales iOS | 18.2 |
| Swift-Version | 5.0 |
| Xcode-Ziel | 15+ |
| Unterstützte Geräte | iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) |
| iPhone-Orientierungen | Portrait, Landscape Left, Landscape Right |
| iPad-Orientierungen | Portrait, Portrait Upside Down, Landscape Left, Landscape Right |

---

## 4. Architektur & Patterns

### Framework-Stack

| Schicht | Technologie |
|---|---|
| UI | SwiftUI (100 %, kein UIViewController außer AppDelegate) |
| Persistenz | Core Data (NSPersistentContainer) |
| Cloud-Sync | CloudKit (privates iCloud-Container) |
| In-App-Käufe | StoreKit 2 (iOS 15+) |
| Nebenläufigkeit | Swift Concurrency (async/await, @MainActor) |
| Karten | MapKit |
| Charts | Swift Charts (WWDC 2022+) |

### Wichtige Architektur-Komponenten

**App Entry Point** – `CamperLogBookApp`
- `@main` WindowGroup
- Environment-Injection des ManagedObjectContext
- LocationManager als @EnvironmentObject
- AppDelegate für Hintergrundaufgaben
- ScenePhase-Beobachtung

**Persistence Layer** – `PersistenceController` (Singleton)
- Lightweight Migration aktiviert
- Merge Policy: `NSMergeByPropertyObjectTrumpMergePolicy`
- Automatisches Zusammenführen aus Parent-Context
- Migration-Recovery mit Backup/Restore-Fallback

**Coordinator-Klassen**
- `CoreDataBackupCoordinator` – Export/Import des Core Data Stores
- `ReceiptBackupCoordinator` – Export/Import von Belegdaten (Binary)

**Manager-Klassen**
- `CloudBackupManager` (Singleton, @MainActor) – iCloud-Backup mit Fortschrittsanzeige (Premium)
- `LocalBackupManager` (Singleton) – ZIP-Backup mit BGAppRefreshTask-Scheduling
- `LocationManager` (@EnvironmentObject) – CoreLocation-Integration
- `PremiumFeatureManager` (Singleton, iOS 15+) – StoreKit 2 IAP-Verwaltung
- `ErrorLogger` – Zentrales Fehler-Logging

---

## 5. Features & Screens

Die App ist als **7-Tab-Architektur** aufgebaut (+ 1 Debug-Tab in DEBUG-Builds):

### Tab 1 – Übersicht
- Dashboard mit Kernmetriken
- Letzte 3 Tankeinträge mit Verbrauchsberechnungen
- Gasflaschen-Verbrauchshochrechnung
- Durchschnittsverbrauch (L/100 km)
- Tage-pro-Gasflasche-Schätzung
- Schnellnavigation zu Einträgen

### Tab 2 – Eintrag (4 Typen)

**A. Tankbeleg (Fuel)**
- Datum, Kraftstoffart (Diesel / Super / Super Plus / AdBlue)
- Aktueller Kilometerstand
- Liter, Preis/Liter, Gesamtkosten
- Voll-/Teilbetankung-Toggle
- Beleg-Erfassung (Foto / PDF / Dokumentenscan via VisionKit)
- Standort (automatisch oder manuell)
- Verbrauchsberechnung, Toast-Benachrichtigung

**B. Gaskosten (Gas)**
- Datum, Flaschenanzahl, Preis/Flasche, Gesamtkosten
- Beleg-Erfassung, Standort

**C. Ver-/Entsorgung (Service)**
- Datum, Versorgung/Entsorgung-Toggle
- Kosten, Frischwassermenge (Liter)
- Beleg-Erfassung, Standort

**D. Sonstige Kosten (Other)**
- Datum, benutzerdefinierte Kategorie, Details, Kosten
- Beleg-Erfassung, Standort

### Tab 3 – Ausgabenliste
- Durchsuchbare Liste aller Einträge (alle Typen)
- Sortierung nach Datum (neueste zuerst)
- Bearbeiten/Löschen per Swipe
- Filter nach Eintragstyp
- Beleg-Vorschau

### Tab 4 – Auswertung
- Balken- und Liniendiagramme (Swift Charts)
- Zeitraum-Filter (individuell und vordefiniert)
- Kategorienfilter (Tankkosten, Gas, Service, Sonstiges)
- Kostenaufschlüsselung nach Monat
- Trendanalyse

### Tab 5 – Wartung
- Wartungsintervall-Tracking
- Km-basierte und zeitbasierte Intervalle
- Dringlichkeitsstatus: Fällig / Bald / OK
- Farbige Icons & Badges
- „Als erledigt markieren"
- Letztes Service-Km/Datum
- TabView-Badge bei überfälligen Einträgen

### Tab 6 – Karte
- MapKit mit geclusterten Annotations
- Zeigt Tankstellen-, Gas- und Service-Standorte
- Gerundete Lat/Lon (4 Dezimalstellen) für Clustering
- Manueller Standort-Picker
- Adress-Lookup und -Umkehr
- Zeitbasierter Filter (3-Monats-Fenster)
- Filter nach Eintragstyp

### Tab 7 – Profil
- Fahrzeugprofil (Kennzeichen, Marke, Typ, Tankvolumen)
- Verwaltung benutzerdefinierter Kategorien (CRUD)
- App-Version-Anzeige
- Startbildschirm-Toggle
- CSV Import/Export
- Backup-Einstellungen

### Tab 8 – Debug (nur DEBUG-Builds)
- Core Data Debug-Hilfsmittel

---

## 6. Datenmodell (Core Data)

### Entitäten

**FuelEntry**

| Attribut | Typ | Anmerkung |
|---|---|---|
| id | UUID | |
| date | Date | |
| fuelType | String | Diesel / Super / Super Plus / AdBlue |
| isDiesel / isAdBlue / isFull | Boolean | |
| currentKm | Int64 | |
| liters | Double | |
| costPerLiter | Double | |
| totalCost | Double | |
| latitude / longitude | Double | |
| roundedLatitude / roundedLongitude | Double | Für Map-Clustering |
| address | String? | |
| receiptData | Binary? | External Storage aktiviert |
| receiptType | String? | `photo` / `pdf` |

**GasEntry**

| Attribut | Typ | Anmerkung |
|---|---|---|
| id | UUID | |
| date | Date | |
| costPerBottle | Double | |
| bottleCount | Int64 | |
| latitude / longitude | Double | |
| roundedLatitude / roundedLongitude | Double | |
| address | String? | |
| receiptData | Binary? | External Storage aktiviert |
| receiptType | String? | |

**ServiceEntry**

| Attribut | Typ | Anmerkung |
|---|---|---|
| id | UUID | |
| date | Date | |
| isSupply / isDisposal | Boolean | |
| cost | Double | |
| freshWater | Double | Liter |
| latitude / longitude | Double | |
| roundedLatitude / roundedLongitude | Double | |
| address | String? | |
| receiptData | Binary? | External Storage aktiviert |
| receiptType | String? | |

**OtherEntry**

| Attribut | Typ | Anmerkung |
|---|---|---|
| id | UUID | |
| date | Date | |
| category | String | |
| details | String? | |
| cost | Double | |
| latitude / longitude | Double | |
| roundedLatitude / roundedLongitude | Double | |
| address | String? | |
| receiptData | Binary? | External Storage aktiviert |
| receiptType | String? | |

**VehicleProfile**

| Attribut | Typ |
|---|---|
| id | UUID |
| licensePlate | String |
| brand | String |
| type | String |
| tankVolume | Double |

**MaintenanceInterval**

| Attribut | Typ | Anmerkung |
|---|---|---|
| id | UUID? | |
| name | String? | |
| intervalKm | Int64 | default 0 |
| intervalMonths | Int64 | default 0 |
| lastServiceKm | Int64 | |
| lastServiceDate | Date? | |
| notes | String? | |
| createdAt | Date? | |

**ExpenseCategory**

| Attribut | Typ |
|---|---|
| id | UUID |
| name | String |

### Persistenz-Features
- External Binary Data Storage für Belegbilder aktiviert
- Automatische Lightweight Migration
- Backup/Restore über Coordinators (Core Data + Receipts)

---

## 7. Capabilities & Entitlements

### Release (`CamperLogBook.entitlements`)
```
com.apple.developer.icloud-services                  → CloudKit
com.apple.developer.icloud-container-identifiers    → iCloud.com.vanityontour.camperlogbook
com.apple.developer.ubiquity-kvstore-identifier     → $(TeamIdentifierPrefix)$(CFBundleIdentifier)
```

### Privacy (`PrivacyInfo.xcprivacy`)
- Datenerfassung: Finanzinformationen (lokal), Präziser Standort (nutzergesteuert)
- Zugegriffene APIs: UserDefaults (CA92.1), File Timestamp (C617.1), Disk Space (E174.1)
- Tracking: deaktiviert

### Info.plist Berechtigungen
- `NSCameraUsageDescription` – Belege einscannen
- `NSLocationWhenInUseUsageDescription` – Einträge verorten
- `BGTaskSchedulerPermittedIdentifiers` → `de.vanityontour.camperlogbook.autobackup`

---

## 8. In-App-Käufe (StoreKit 2)

| Produkt | Product ID | Typ | Preis (geplant) |
|---|---|---|---|
| iCloud-Backup | `com.vanityontour.camperlogbook.icloudbackup` | Non-Consumable | 4,99 € |
| Pro Analytics | *(geplant)* | Non-Consumable | ~2,99 € |
| Vanity Pro Bundle | *(geplant)* | Non-Consumable | ~4,99 € |

**Implementierungsdetails:**
- `PremiumFeatureManager` verwaltet Transaktionen und Verifizierung
- Persistenz in UserDefaults
- DEBUG-Builds schalten alle Features automatisch frei
- Transaktionsverifizierung über Apple-Server

---

## 9. Build Targets

| Target | Bundle ID | Typ |
|---|---|---|
| CamperLogBook | `VanityOnTour.CamperLogBook` | Application |
| CamperLogBookTests | `VanityOnTour.CamperLogBookTests` | Unit Test Bundle |
| CamperLogBookUITests | `VanityOnTour.CamperLogBookUITests` | UI Test Bundle |

**Widget Extension (vorbereitet, noch kein eigenes Target):**
- Code vorhanden: `ExpenseWidget.swift`, `ExpenseWidgetEntry.swift`, `ExpenseWidgetProvider.swift`, `ExpenseWidgetView.swift`
- Unterstützte Familien: `systemSmall`, `systemMedium`
- Inhalt: Monatsausgaben-Zusammenfassung, letzter Tankeintrag
- Empfohlene Bundle ID: `de.vanityontour.camperlogbook.widget`
- Benötigt: Separates Widget Extension Target + App Group

---

## 10. Abhängigkeiten

### Apple-Frameworks (alle nativ, keine Drittanbieter)
```
AVFoundation        BackgroundTasks     Charts
CloudKit            Combine             Compression
CoreData            CoreLocation        Foundation
MapKit              MessageUI           PDFKit
PhotosUI            Security            StoreKit
SwiftUI             UIKit               UniformTypeIdentifiers
UserNotifications   VisionKit           WidgetKit
```

### Ruby Gems (Build/Deploy)
```ruby
gem "fastlane", "~> 2.228"
```

**Keine CocoaPods, keine Swift Package Manager-Abhängigkeiten.**

---

## 11. Lokalisierung

- **Aktuell:** Nur Deutsch (`de`)
- **Development Region:** `de`
- **Zahlenformat:** `de_DE` (Komma als Dezimaltrenner, z. B. 1,50 €)
- **Datumsformate:** dd.MM.yy / dd.MM.yyyy / yyyy-MM-dd
- **Geplant:** Englisch (Phase 4, Issue #44, ~10 h Aufwand)

---

## 12. Tests

### Unit Tests (`CamperLogBookTests/`)

| Datei | Abdeckung |
|---|---|
| `ConsumptionTests.swift` | Kraftstoff-Verbrauchsberechnungen |
| `PremiumFeatureManagerTests.swift` | StoreKit 2 IAP-Integration |
| `ModelsTests.swift` | Core Data Modell-Validierung |
| `BackupTests.swift` | Backup/Restore-Funktionalität |
| `CSVHelperTests.swift` | CSV Import/Export-Parsing |
| `CamperLogBookTests.swift` | Allgemeine App-Tests |
| `Helpers/CoreDataTestStack.swift` | Core Data Test-Fixture |

### UI Tests (`CamperLogBookUITests/`)
- `ScreenshotsUITests.swift` – Fastlane-Snapshot-Test
- `SnapshotHelper.swift` – Screenshot-Automatisierung

---

## 13. Fastlane

**Konfigurierte Lane:**
```ruby
lane :screenshots do
  snapshot(
    scheme: "CamperLogBook",
    project: "CamperLogBook.xcodeproj",
    reinstall_app: true,
    clear_previous_screenshots: true,
    result_bundle: true,
    testplan: "Screenshots",
    concurrent_simulators: false
  )
end
```
Zweck: Automatische App-Store-Screenshot-Generierung.

---

## 14. CI/CD Pipeline

### GitHub Actions Workflows

| Datei | Trigger | Bedingung |
|---|---|---|
| `ci.yml` | Push/PR auf main, develop, release/*, fix/*, feature/* | `USE_VANITY_DEV_ENGINE != 'true'` |
| `use-vanity-dev-engine.yml` | Push/PR | `USE_VANITY_DEV_ENGINE == 'true'` |
| `version-guard.yml` | PR | Immer – validiert MARKETING_VERSION-Bump |
| `secret-scan.yml` | Push/PR | Immer – Gitleaks |
| `issue-close-on-merge.yml` | PR merge | Immer – schließt verknüpfte Issues |
| `ai-review.yml` | PR | Immer – ChatGPT Review |

**Lokale CI-Jobs (`ci.yml`):**
1. SwiftLint (`swiftlint --strict`)
2. Build (iPhone 16 Simulator, `CODE_SIGNING_ALLOWED=NO`)
3. Test (iPhone 16 Simulator)

**Remote Pipeline (`vanity-dev-engine`):**
- Reusable Workflow: `OliverGiertz/vanity-dev-engine/.github/workflows/repo-pipeline.yml@v1.9`
- Jobs: ci, security-scan (Gitleaks + Semgrep), ai-review (ChatGPT + Claude-Validierung)

### AI Review Gate (CLAUDE.md)
- Zwei Reviews erforderlich (Claude Code lokal + ChatGPT automatisch)
- Beide müssen `DoD status: PASS`, `Blocker: 0`, `Major: 0` vorweisen
- Claude-Kommentar wird manuell via `gh pr comment` gepostet

---

## 15. Backup-Strategie

### Lokales Backup (`LocalBackupManager`)
- ZIP-Archive mit Core Data Store + Belegdaten
- Speicherort: App's Documents-Ordner
- Automatisches Scheduling via `BGAppRefreshTask`
- Task-ID: `de.vanityontour.camperlogbook.autobackup`

### iCloud-Backup (`CloudBackupManager`)
- CloudKit Private Database
- Premium-Feature (IAP-pflichtig)
- Thread-sicheres Design mit Fortschrittsanzeige

---

## 16. Roadmap (5 Phasen)

| Phase | Zeitraum | Schwerpunkt |
|---|---|---|
| Phase 1 | KW 9–10 | Stabilität & Sicherheit (Force-Cast-Fixes, Privacy Manifest, Backup-Bugs) |
| Phase 2 | KW 11–12 | Performance & Dev-Infrastruktur (Async, Map-Clustering, SwiftLint, CI/CD) |
| Phase 3 | KW 13–16 | Monetarisierung / v3.0 (IAPs: Cloud Backup, Pro Analytics, Vanity Pro Bundle) |
| Phase 4 | KW 17–22 | Core-Features & Qualität (Tests, Accessibility, iPad, Englisch, Suche/Filter) |
| Phase 5 | Q3/Q4 2026 | Erweiterte Features (Multi-Fahrzeug, Widget, Biometrie, PDF-Export, Siri) |

**Geplante Phase-5-Features:**
- Multi-Fahrzeugprofile
- iOS Widget (Code bereits vorbereitet)
- Biometrische Authentifizierung
- Wartungserinnerungen (Push-Notifications)
- PDF-Export
- Kraftstoffpreis-Tracking
- iCloud-Sync (vollständig)
- Siri Shortcuts
- Reisetagebuch

**Preisstrategie:**
- App: 0,99 €
- IAP Cloud & Backup: ~2,99 €
- IAP Pro Analytics: ~2,99 €
- Vanity Pro Bundle: ~4,99 €

**KPIs:**
- ≥ 99,5 % Crash-free Sessions
- ≥ 4,5 ⭐ App Store Bewertung
- ≥ 5 % IAP-Conversion
- ≥ 60 % Test-Coverage (Phase 4)

---

## 17. Schnellreferenz

| Kategorie | Detail |
|---|---|
| Name | Vanity Expense Logbook |
| Bundle ID | `VanityOnTour.CamperLogBook` |
| Version | 3.0.1 (Build 26.3.01) |
| Min. iOS | 18.2 |
| Sprache | Deutsch (de) |
| Plattform | iPhone + iPad |
| Framework | SwiftUI + CoreData + CloudKit |
| Tabs | 7 (+ 1 Debug) |
| Eintragstypen | 4 (Tankbelege, Gas, Ver-/Entsorgung, Sonstiges) |
| Core Data Entitäten | 7 |
| Capabilities | iCloud, Standort, Kamera, Fotos, VisionKit, BGAppRefreshTask |
| IAPs | 3 geplant (Cloud Backup, Pro Analytics, Vanity Pro Bundle) |
| CI/CD | GitHub Actions (lokal + vanity-dev-engine remote) |
| Tests | Unit Tests + UI Tests (Screenshots) |
| Drittanbieter-Deps | Keine (nur native Apple-Frameworks) |
