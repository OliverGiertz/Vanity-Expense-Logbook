# CHANGELOG

Dieses Dokument listet alle relevanten Änderungen (Features, Fixes, Änderungen) pro Version in absteigender Reihenfolge. Datumsformat: YYYY-MM-DD.

## [2.3.1] - 2025-09-06
- Neu: Gemischter CSV-Import ohne Typauswahl in der UI. Import entscheidet pro Zeile anhand der Spalte `entryType` (FuelEntry, GasEntry, OtherEntry) bzw. heuristisch, wenn die Spalte fehlt.
- Neu: Import-Zusammenfassung pro Typ (z. B. „Tank/Gas/Sonstige“) und klarere Fehlermeldung, wenn 0 Einträge importiert wurden.
- Änderung: CSV-Import erkennt Trennzeichen automatisch (Tab, Semikolon, Komma) und entfernt ggf. UTF-8 BOM.
- Verbesserung: Robusteres Parsing für Datum (Formate: `dd.MM.yy`, `dd.MM.yyyy`, `yyyy-MM-dd`) und Booleans (`1/0`, `true/false`, `ja/nein`).
- Änderung: Export und Import sind kompatibel (u. a. Spalte `entryType`, Tab-getrennt).
- Wartung: App-Version auf 2.3.1 angehoben.

## [2.3.0] - 2025-08-23
- Verbesserung: UI-Navigation für Eingabeformulare optimiert.

## [Build 25.03.0] - 2025-03-15
- Änderung: Backup-Bereich aus der Profilansicht entfernt.

## [Build 25.02.6] - 2025-03-01
- Fix: Backup/Restore-Probleme behoben und Manifest-Handling verbessert.

## [Build 25.02.5] - 2025-02-27
- Wartung: Code-Optimierungen und kleinere Bereinigungen.

## [Build 25.02.4] - 2025-02-27
- Neu: Standort-Umschalter und manuelle Adresssuche.
- Änderung: Belegdaten werden beim Editieren zurückgesetzt.
- Verbesserung: Kamera-Berechtigungsprüfung im DocumentScannerView.

## [Build 25.02.3] - 2025-02-25
- Interne Verbesserungen und Überblick-Anpassungen.

## [2.2.2] (Build 25.02.22.1) - 2025-02-22
- Verbesserung: Overview & Core Data Optimierungen.

## [2.2.1] - 2025-02-21
- Feature: Frischwasser-Feld in ServiceEntry-Formulare.

## [2.2.0] - 2025-02-19
- Verschiedene Funktionsverbesserungen (siehe Commit Summary).

## [2.1.9] - 2025-02-19
- Kleinere Verbesserungen und Aufräumarbeiten (siehe Commit Summary).

## 2.1.x (2025-02-15 – 2025-02-16)
- Feature: Import/Export-Funktion hinzugefügt; Auswertung angepasst; Profilansicht erweitert.
- Feature: Belegerfassung erweitert (Fotos, Dateizugriff, Dokumentenscan über Kamera).
- UI: Startseite mit Appname und Versionsnummer; Startseite optional deaktivierbar; Profil zeigt Versionsnummer.
- Docs: README hinzugefügt.
- Wartung: Ordnerstruktur reorganisiert; DRY-Prinzip umgesetzt; zentrale Utilities (z. B. ReceiptPickerSheet) eingeführt.
