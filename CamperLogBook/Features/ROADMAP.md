# Vanity Expense Logbook – Roadmap

> Letzte Aktualisierung: 28. Februar 2026 | Aktuelle Version: 2.3.3

---

## Monetarisierungsstrategie

| Produkt | Preis | Zielgruppe |
|---|---|---|
| **App (Basisversion)** | 0,99€ | Alle – alle Kernfunktionen enthalten |
| **IAP 1: Cloud & Backup** | ~2,99€ | Nutzer die ihre Daten sichern wollen |
| **IAP 2: Pro Analytics** | ~2,99€ | Nutzer die detaillierte Auswertungen brauchen |
| **Vanity Pro Bundle** | ~4,99€ | Power-User – alle Features + alle zukünftigen |

---

## Phasen-Übersicht

```
Phase 1 │ Phase 2 │ Phase 3 │ Phase 4 │ Phase 5
Stabil  │ Perf.   │ IAPs    │ Features │ Extended
KW9–10  │ KW11–12 │ KW13–16 │ KW17–22  │ Q3/Q4 2026
```

---

## Phase 1 – Stabilität & Security
**Zeitraum:** KW9–10 2026 (Start: 01.03.2026) | **Milestone:** [GitHub #1](https://github.com/OliverGiertz/Vanity-Expense-Logbook/milestone/1)

Ziel: Crash-Risiken beseitigen und App-Store-Compliance sicherstellen, bevor neue Features entwickelt werden.

### Reihenfolge der Umsetzung

#### 1. Force Cast Crash Fix – [Issue #26](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/26)
**Priorität:** P0 | **Aufwand:** ~1h | **Label:** bug

Force Casts (`as!`) in `Models.swift` durch typsichere Initialisierung ersetzen.

```swift
// Vorher – Crash-Risiko:
FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>

// Nachher – sicher:
NSFetchRequest<FuelEntry>(entityName: "FuelEntry")
```

Betroffene Dateien: `Core/Models/Models.swift` (4 Stellen)

---

#### 2. Auto-Backup Bug Fix – [Issue #30](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/30)
**Priorität:** P0 | **Aufwand:** ~2h | **Label:** bug

`scheduleNextAutomaticBackup()` löst nur eine Notification aus, führt aber kein Backup durch. `BGAppRefreshTask`-Handler mit tatsächlichem Backup-Aufruf verbinden.

Betroffene Dateien: `Features/Backup/LocalBackupManager.swift`, `Features/Backup/AppDelegate.swift`

---

#### 3. Backup-Ordner Cleanup Fix – [Issue #25](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/25)
**Priorität:** P0 | **Aufwand:** ~30min | **Label:** bug

Nach der ZIP-Erstellung verbleibt der unkomprimierte Ordner in `Documents/`. Eine Zeile ergänzen:

```swift
try FileManager.default.removeItem(at: backupFolderURL) // nach ZIP-Erstellung
```

Betroffene Datei: `Features/Backup/LocalBackupManager.swift` (~Zeile 245)

---

#### 4. Privacy Manifest – [Issue #50](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/50)
**Priorität:** P0 | **Aufwand:** ~2h | **Label:** security

`PrivacyInfo.xcprivacy` erstellen und alle genutzten Required-Reason-APIs deklarieren (UserDefaults, File APIs). Apple-Pflicht seit 2024 – ohne Manifest kann der App-Store-Upload abgelehnt werden.

---

## Phase 2 – Performance & Dev-Infrastruktur
**Zeitraum:** KW11–12 2026 | **Milestone:** [GitHub #2](https://github.com/OliverGiertz/Vanity-Expense-Logbook/milestone/2)

Ziel: Sichtbare Performance-Probleme beheben und die Entwicklungsinfrastruktur für spätere Phasen vorbereiten.

#### 5. AnalysisView Async Fix – [Issue #27](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/27)
**Priorität:** P1 | **Aufwand:** ~3h | **Label:** performance, bug

4 synchrone CoreData-Fetches auf Main Thread → UI-Freeze. In einen `Task { }` mit Background-Kontext verlagern.

#### 6. Map Annotation Clustering – [Issue #29](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/29)
**Priorität:** P2 | **Aufwand:** ~4h | **Label:** performance

`clusteringIdentifier` für alle Map-Annotations setzen; bei vielen Einträgen deutliche Performance-Verbesserung.

#### 7. SwiftLint Integration – [Issue #42](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/42)
**Priorität:** P1 | **Aufwand:** ~2h | **Label:** technical-debt, good first issue

`.swiftlint.yml` + Xcode Build Phase einrichten. Verhindert zukünftige Force-Cast-Regressions automatisch.

#### 8. GitHub Actions CI/CD – [Issue #47](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/47)
**Priorität:** P1 | **Aufwand:** ~4h | **Label:** enhancement

Automatischer Build + (später) Test-Check bei jedem PR. Basis für sichere Weiterentwicklung.

---

## Phase 3 – Monetarisierung (v3.0)
**Zeitraum:** KW13–16 2026 | **Milestone:** [GitHub #3](https://github.com/OliverGiertz/Vanity-Expense-Logbook/milestone/3)

Ziel: Revenue-Streams implementieren und in den App Store bringen.

#### 9. IAP 1: Cloud & Backup – [Issue #51](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/51)
**Priorität:** P0 | **Aufwand:** ~8h

Backup (lokal + iCloud) als IAP (~2,99€). Bestehende `icloudbackup`-Käufer migrieren. Paywall-View in BackupRestoreView integrieren.

**Produkt-ID:** `com.vanityontour.camperlogbook.cloudbackup`

#### 10. IAP 2: Pro Analytics – [Issue #53](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/53)
**Priorität:** P1 | **Aufwand:** ~10h

PDF-Berichte, Kraftstoffpreis-Trends, erweiterte Suche als IAP (~2,99€). Paywall in AnalysisView und ImportExportView.

**Produkt-ID:** `com.vanityontour.camperlogbook.proanalytics`

#### 11. Vanity Pro Bundle – [Issue #52](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/52)
**Priorität:** P1 | **Aufwand:** ~4h

Bundle-Produkt in App Store Connect anlegen (~4,99€). `PremiumFeatureManager` so erweitern, dass Pro alle Einzelkäufe impliziert.

**Produkt-ID:** `com.vanityontour.camperlogbook.vanitypro`

---

## Phase 4 – Core Features & Qualität
**Zeitraum:** KW17–22 2026 | **Milestone:** [GitHub #4](https://github.com/OliverGiertz/Vanity-Expense-Logbook/milestone/4)

Ziel: App professionalisieren, technische Schulden abbauen, Nutzerbasis erweitern.

| Issue | Titel | Aufwand |
|---|---|---|
| [#43](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/43) | Code-Duplikation in Entry-Formularen | ~4h |
| [#31](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/31) | Unit Tests implementieren | ~12h |
| [#41](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/41) | async/await Migration | ~8h |
| [#35](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/35) | Suche & Filter (Teil von Pro Analytics IAP) | ~6h |
| [#32](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/32) | Accessibility (VoiceOver, Dynamic Type) | ~6h |
| [#49](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/49) | Haptic Feedback | ~2h |
| [#38](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/38) | iPad & Landscape-Support | ~8h |
| [#44](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/44) | Lokalisierung (Englisch) | ~10h |
| [#28](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/28) | receiptData externalisieren (CoreData-Migration) | ~6h |

---

## Phase 5 – Extended Features
**Zeitraum:** Q3/Q4 2026 | **Milestone:** [GitHub #5](https://github.com/OliverGiertz/Vanity-Expense-Logbook/milestone/5)

Ziel: Bundle-exklusive Features und Long-Term-Vision umsetzen.

| Issue | Titel | IAP | Aufwand |
|---|---|---|---|
| [#33](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/33) | Mehrere Fahrzeugprofile | Vanity Pro | ~12h |
| [#34](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/34) | iOS Widget | Vanity Pro | ~8h |
| [#36](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/36) | Biometrische Authentifizierung | Vanity Pro | ~3h |
| [#37](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/37) | Wartungsintervalle & Erinnerungen | Vanity Pro | ~8h |
| [#40](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/40) | PDF-Bericht Export | Pro Analytics | ~6h |
| [#45](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/45) | Kraftstoffpreis-Tracking | Pro Analytics | ~4h |
| [#46](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/46) | iCloud Live-Sync | Cloud & Backup | ~16h |
| [#39](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/39) | Siri Shortcuts / App Intents | Vanity Pro | ~8h |
| [#48](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues/48) | Reisetagebuch | Vanity Pro | ~10h |

---

## KPIs

| Metrik | Ziel |
|---|---|
| Crash-free Rate | > 99,5% |
| App-Store Rating | > 4,5 ⭐ |
| IAP Conversion Rate | > 5% (von Downloads) |
| Test Coverage | > 60% Business-Logik (Phase 4) |

---

## GitHub

- **Issues:** [github.com/OliverGiertz/Vanity-Expense-Logbook/issues](https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues)
- **Project Board:** [github.com/users/OliverGiertz/projects/2](https://github.com/users/OliverGiertz/projects/2)
- **Milestones:** [github.com/OliverGiertz/Vanity-Expense-Logbook/milestones](https://github.com/OliverGiertz/Vanity-Expense-Logbook/milestones)

---

_Roadmap wird bei jedem Sprint-Abschluss aktualisiert._
