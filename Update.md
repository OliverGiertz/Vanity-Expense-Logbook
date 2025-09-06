# Updateverlauf (Changelog)

Dieses Dokument listet alle relevanten Änderungen (Features, Fixes, Änderungen) pro Version. 
Daten sind im Format YYYY-MM-DD angegeben.

## [2.3.1] - 2025-09-06

- Neu: Gemischter CSV-Import ohne Typauswahl in der UI. Import entscheidet pro Zeile anhand der Spalte `entryType` (FuelEntry, GasEntry, OtherEntry) bzw. heuristisch, wenn die Spalte fehlt.
- Neu: Import-Zusammenfassung pro Typ (z. B. „Tank/Gas/Sonstige“) und klarere Fehlermeldung, wenn 0 Einträge importiert wurden.
- Änderung: CSV-Import erkennt Trennzeichen automatisch (Tab, Semikolon, Komma) und entfernt ggf. UTF-8 BOM.
- Verbesserung: Robusteres Parsing für Datum (Formate: `dd.MM.yy`, `dd.MM.yyyy`, `yyyy-MM-dd`) und Booleans (`1/0`, `true/false`, `ja/nein`).
- Änderung: Export und Import sind kompatibel (u. a. Spalte `entryType`, Tab-getrennt).
- Wartung: App-Version auf 2.3.1 angehoben.

## Hinweise
- Ältere Versionen werden sukzessive aus Git-Tags/Release-Notes nachgetragen, sofern erforderlich.

