# Claude Code Guidelines – Vanity Expense Logbook

## Workflow

Direkter Push auf `main` – kein Pull Request erforderlich.

Vor jedem Push:
1. **Claude-Review** lokal durchführen (`git diff main` analysieren – Code-Qualität, keine Secrets)
2. **Version bumpen** in `CamperLogBook.xcodeproj/project.pbxproj`
3. Committen und direkt auf `main` pushen

## Versioning Convention

Jeder Commit auf `main` muss `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` erhöhen.

Format `CURRENT_PROJECT_VERSION`: `JJ.Major.MinorPatch`
- `JJ` = letzte zwei Ziffern des Jahres (z.B. 26 für 2026)
- `Major` = Major-Versionsnummer
- `MinorPatch` = Minor + Patch zusammengeführt

Beispiel: Version `3.1.0` → Build `26.3.10`

## CI (GitHub Actions)

Zwei lightweight Checks laufen automatisch bei jedem Push auf `main`:

- **version-guard** – prüft ob `MARKETING_VERSION` gegenüber dem vorherigen Commit erhöht wurde
- **secret-scan** – Gitleaks scannt auf versehentlich eingecheckte Secrets/Keys

Bei Fehler: Ursache beheben, Version nochmals bumpen, erneut pushen.

## Testing

- **Lokal**: Xcode Tests vor jedem Push ausführen (`Cmd+U`)
- **Xcode Cloud**: Läuft vor jedem App Store Release – vollständiger Test-Durchlauf + Archivierung

Xcode-Tests sollen die zentrale Qualitätssicherung sein und kontinuierlich ausgebaut werden.
