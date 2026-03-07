# Use Vanity Dev Engine

## Zweck

Dieses Dokument beschreibt den verbindlichen Ablauf, um App-Weiterentwicklungen über die zentrale Pipeline `vanity-dev-engine` zu steuern.

Ziel:

- Updates automatisiert entwickeln lassen
- Fehler automatisiert finden
- Findings beheben
- nur bei komplett gruenen Gates mergen

## Technische Basis

- Zentrale Engine: `OliverGiertz/vanity-dev-engine`
- Reusable Workflow: `.github/workflows/repo-pipeline.yml@v1.5`
- Consumer Workflow: `.github/workflows/use-vanity-dev-engine.yml`
- Aktivierung per Repo-Variable: `USE_VANITY_DEV_ENGINE=true`

## Erzwungene Gates (main)

Branch Protection verlangt:

- `use-vanity-dev-engine / ci`
- `use-vanity-dev-engine / security-scan`
- `use-vanity-dev-engine / ai-review`
- 1 PR Approval
- Conversation Resolution
- Up-to-date Branch (`strict`)

## Standardablauf fuer Weiterentwicklungen

1. Feature-Branch erstellen.
2. Aenderungen umsetzen (Code + Tests).
3. PR oeffnen.
4. AI-Reviews nach AGENTS.md durchfuehren und in PR-Template eintragen.
5. Auf die drei zentralen Checks warten.
6. Findings komplett beheben und erneut pushen.
7. Merge erst wenn alle Gates gruen sind.

## Pflichtformat fuer AI-Reviews

In der PR-Beschreibung muessen fuer **ChatGPT** und **Claude** vorhanden sein:

- `Blocker: 0`
- `Major: 0`
- `DoD status: PASS`

Fehlt eines davon, failt `ai-review`.

## Verwendung in neuen Repositories

1. Workflow-Datei anlegen:

```yaml
name: use-vanity-dev-engine

on:
  pull_request:
    branches: ["**"]
  push:
    branches: [main, develop, "release/**", "fix/**", "feature/**"]

jobs:
  use-vanity-dev-engine:
    if: ${{ vars.USE_VANITY_DEV_ENGINE == 'true' }}
    uses: OliverGiertz/vanity-dev-engine/.github/workflows/repo-pipeline.yml@v1.5
    with:
      repo_type: ios
      xcode_project: CamperLogBook.xcodeproj
      xcode_scheme: CamperLogBook
```

2. Repo-Variable setzen: `USE_VANITY_DEV_ENGINE=true`
3. Branch-Protection auf zentrale Check-Namen setzen.
4. PR-Template mit AI-Review-Sektionen verwenden.

## Betrieb und Updates

- Bei Engine-Updates immer versioniert umstellen (`@v1.5`, `@v1.6`, ...), nie unversioniert.
- Nach jedem Versionssprung einen Test-PR laufen lassen.
- Wenn zentrale Pipeline stoert, kann temporaer `USE_VANITY_DEV_ENGINE=false` gesetzt werden (Fallback auf lokale Workflows, falls vorhanden).

Hinweis fuer iOS-Repos:

- Die zentrale CI laeuft standardmaessig auf `ubuntu-latest`.
- Fuer echte iOS-Builds/Tests entweder `build_command` und `test_command` explizit setzen oder Xcode Cloud verwenden.

## Prompt-Vorlage fuer künftige Entwicklungsaufgaben

"Nutze AGENTS.md + Use Vanity Dev Engine. Setze die Aenderung in einem Feature-Branch um, aktualisiere Tests, fuehre AI-Review im Pflichtformat durch und stelle sicher, dass `use-vanity-dev-engine / ci`, `security-scan`, `ai-review` gruen sind. Danach PR-merge vorbereiten."
