# Changelog

Alle bemerkenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt hält sich an [Semantic Versioning](https://semver.org/lang/de/).

---

## [Unreleased]

### Geplant
- Widgets für den Home Screen
- OCR für Belege
- Mehrere Fahrzeugprofile
- Erweiterte Statistiken

---

## [1.1.0] - 2026-02-28

### ✨ Hinzugefügt
- **Premium-Feature:** iCloud Backup als In-App-Purchase (Einmalkauf 4,99€)
  - Automatische Backups in iCloud
  - Einfache Wiederherstellung auf allen Geräten
  - End-to-End verschlüsselt
- `PremiumFeatureManager` für StoreKit 2 Integration
- `PremiumBackupView` - Elegante Paywall
- `BackupSettingsView` - Backup-Verwaltung nach Kauf
- Automatische Backup-Funktion (täglich um 2:00 Uhr)
- Fortschrittsanzeige für Backup und Restore
- Debug-Modus: Premium-Features in DEBUG automatisch freigeschaltet

### 🔄 Geändert
- Backup-Funktionen aus dem Standard-Profil entfernt
- ProfileView um Premium-Section erweitert
- Verbesserte Fehlerbehandlung in CloudBackupManager
- UI-Verbesserungen in Backup-Flows

### 🐛 Behoben
- Memory-Leaks in Backup-Closures durch `[weak self]`
- Crash bei fehlenden GPS-Daten in FuelMapView
- Inkonsistente Datumsformatierung in verschiedenen Locales

### 📚 Dokumentation
- ROADMAP.md mit 25+ Verbesserungsvorschlägen erstellt
- PREMIUM_IMPLEMENTATION.md für In-App-Purchase Guide
- CONTRIBUTING.md für Contributors
- GitHub Issue Templates hinzugefügt
- README.md aktualisiert

---

## [1.0.0] - 2026-01-15

### ✨ Initial Release

#### Core Features
- **Tankbelege** erfassen mit GPS-Koordinaten
- **Gaskosten** verwalten mit Flaschen-Tracking
- **Service-Einträge** für Ver- und Entsorgung
- **Sonstige Kosten** kategorisieren
- **Übersicht** mit Durchschnittsverbrauch
- **Auswertungen** als Diagramme (Bar & Line Charts)
- **Kartenansicht** mit Tankstellen-Pins
- **Fahrzeugprofil** mit Stammdaten

#### Backend
- CoreData für lokale Datenspeicherung
- LocationManager mit GPS-Integration
- Lokale Backup-Funktion (CSV Export)
- ErrorLogger für zentrale Fehlerprotokollierung

#### UI/UX
- SwiftUI-basierte moderne Oberfläche
- Tab-basierte Navigation
- Dark Mode Support
- Deutsche Lokalisierung
- Ansprechende Formular-Komponenten

#### Data Management
- CoreData Entities: FuelEntry, GasEntry, ServiceEntry, OtherEntry
- VehicleProfile für Fahrzeugdaten
- ExpenseCategory für Kategorisierung
- Automatisches GPS-Tagging

#### Analytics
- Durchschnittsverbrauch pro 100km
- Tage pro Gasflasche
- Kostenauswertung nach Zeitraum
- Heatmap-Darstellung auf Karte

---

## Versionierungsschema

### MAJOR.MINOR.PATCH

- **MAJOR:** Breaking Changes, API-Änderungen
- **MINOR:** Neue Features, abwärtskompatibel
- **PATCH:** Bug Fixes

---

## Labels

- ✨ **Hinzugefügt** - Neue Features
- 🔄 **Geändert** - Änderungen an existierenden Features
- 🗑️ **Entfernt** - Entfernte Features
- 🐛 **Behoben** - Bug Fixes
- 🔒 **Sicherheit** - Security-relevante Änderungen
- 📚 **Dokumentation** - Dokumentations-Updates
- ⚡ **Performance** - Performance-Verbesserungen
- ♿ **Accessibility** - Barrierefreiheit

---

## Migration Guides

### Von 1.0.0 zu 1.1.0

#### Breaking Changes
Keine - vollständig abwärtskompatibel.

#### Neue Features nutzen

**iCloud Backup aktivieren:**
1. Profil → Premium Features → iCloud Backup freischalten
2. Kaufe das Feature für 4,99€
3. Nach Freischaltung: Backup-Einstellungen öffnen
4. "Backup jetzt erstellen" klicken

**Automatische Backups:**
1. Backup-Einstellungen öffnen
2. "Automatisches Backup" aktivieren
3. App erstellt täglich um 2:00 Uhr ein Backup

#### Datenübernahme
Alle existierenden Daten bleiben erhalten. Keine Migration notwendig.

---

## Bekannte Probleme

### 1.1.0
- [ ] Map-Clustering bei > 100 Pins kann langsam sein
- [ ] Sehr große Backups (> 500 MB) können Timeout verursachen
- [ ] OCR-Feature noch nicht verfügbar

### Lösungen in Arbeit
- Map-Performance-Optimierung (#10 in ROADMAP.md)
- Streaming für große Backup-Dateien (#22)
- OCR-Integration geplant für v1.2.0 (#14)

---

## Support

Bei Fragen oder Problemen:
- GitHub Issues: https://github.com/OliverGiertz/Vanity-Expense-Logbook/issues
- Discussions: https://github.com/OliverGiertz/Vanity-Expense-Logbook/discussions

---

[Unreleased]: https://github.com/OliverGiertz/Vanity-Expense-Logbook/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/OliverGiertz/Vanity-Expense-Logbook/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/OliverGiertz/Vanity-Expense-Logbook/releases/tag/v1.0.0
