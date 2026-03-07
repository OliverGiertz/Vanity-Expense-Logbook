# Issue Workflow (Merge Automation)

## Ziel

Bei jeder umgesetzten Aufgabe soll im verknuepften Issue ein Abschluss-Kommentar mit Aenderungen und Pruefstatus stehen. Danach wird das Issue automatisch geschlossen.

## Pflicht im PR-Body

Damit die Automation das richtige Issue findet, muss der PR-Body einen Closing-Keyword enthalten, z. B.:

- `Fixes #123`
- `Closes #123`
- `Resolves #123`

Mehrere Issues sind moeglich, z. B. `Fixes #123` und `Closes #124`.

## Was automatisch passiert (bei Merge)

Workflow: `.github/workflows/issue-close-on-merge.yml`

- liest die per Closing-Keyword verknuepften Issues
- schreibt einen Kommentar ins Issue mit:
  - geaenderten Dateien (Auszug)
  - zentralen Check-Ergebnissen
  - PR-Link und Merge-Commit
- schliesst das Issue

## Voraussetzungen

- PR wurde erfolgreich gemerged
- zentrale Checks waren erfolgreich
- Issue-Nummer ist im PR-Body referenziert

## Empfehlung fuer neue PRs

Im PR-Body immer eine Zeile mit `Fixes #<IssueNummer>` aufnehmen.
