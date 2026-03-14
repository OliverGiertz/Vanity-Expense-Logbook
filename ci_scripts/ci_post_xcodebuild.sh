#!/bin/sh
# ci_scripts/ci_post_xcodebuild.sh
#
# Xcode Cloud führt dieses Skript nach jeder Action (Build / Test / Archive) aus.
# Bei Test-Fehlern wird automatisch ein GitHub Issue angelegt.
#
# Benötigte Xcode Cloud Environment Variable (als Secret setzen):
#   GITHUB_TOKEN  →  Personal Access Token mit Scope "repo"

set -e

# Nur bei der Test-Action und nur bei Fehler aktiv werden
if [ "$CI_XCODEBUILD_ACTION" != "test" ]; then
  echo "ci_post_xcodebuild: Action ist '$CI_XCODEBUILD_ACTION' – kein Issue nötig."
  exit 0
fi

if [ "$CI_XCODEBUILD_EXIT_CODE" = "0" ]; then
  echo "✅  Tests erfolgreich – kein Issue wird angelegt."
  exit 0
fi

echo "❌  Tests fehlgeschlagen (Exit-Code: $CI_XCODEBUILD_EXIT_CODE) – lege GitHub Issue an …"

# ── Pflichtfeld prüfen ────────────────────────────────────────────────────────
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "⚠️   GITHUB_TOKEN nicht gesetzt – Issue wird nicht erstellt."
  echo "     Bitte in Xcode Cloud → Workflow → Environment → Secrets eintragen."
  exit 0
fi

# ── Metadaten zusammenstellen ─────────────────────────────────────────────────
REPO="OliverGiertz/Vanity-Expense-Logbook"
BRANCH="${CI_BRANCH:-unbekannt}"
COMMIT="${CI_COMMIT:-unbekannt}"
BUILD_NUM="${CI_BUILD_NUMBER:-?}"
WORKFLOW="${CI_WORKFLOW:-?}"
DATE=$(date '+%d.%m.%Y %H:%M')

# Version aus project.pbxproj lesen
VERSION=$(grep MARKETING_VERSION "$CI_WORKSPACE/CamperLogBook.xcodeproj/project.pbxproj" \
  | head -1 | tr -d ' ;' | cut -d= -f2 2>/dev/null || echo "?")

TITLE="🐛 [Xcode Cloud] Test-Fehler v${VERSION} – ${DATE} (${BRANCH}@${COMMIT:0:7})"

BODY=$(cat <<EOF
## ❌ Test-Fehler in Xcode Cloud

| | |
|---|---|
| **Version** | v${VERSION} |
| **Branch** | \`${BRANCH}\` |
| **Commit** | \`${COMMIT:0:7}\` |
| **Build** | #${BUILD_NUM} |
| **Workflow** | ${WORKFLOW} |
| **Datum** | ${DATE} |

## Nächster Schritt

Test-Ergebnisse in Xcode Cloud einsehen:
- Xcode → Report Navigator (CMD+9) → Cloud-Tab → Build #${BUILD_NUM}

Oder direkt im Browser:
- App Store Connect → Xcode Cloud → Builds

## Beheben

Dieses Issue Claude zur Behebung übergeben:
1. Issue öffnen
2. Fehlerdetails aus Xcode Cloud Log kopieren
3. Claude beauftragen: *"Bitte behebe die Fehler aus Issue #..."*

---
*Automatisch erstellt durch \`ci_scripts/ci_post_xcodebuild.sh\`*
EOF
)

# ── GitHub Issue via API anlegen ──────────────────────────────────────────────
HTTP_STATUS=$(curl -s -o /tmp/gh_issue_response.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${REPO}/issues" \
  --data "{
    \"title\": $(echo "$TITLE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'),
    \"body\":  $(echo "$BODY"  | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'),
    \"labels\": [\"bug\"]
  }")

if [ "$HTTP_STATUS" = "201" ]; then
  ISSUE_URL=$(python3 -c "import json; d=json.load(open('/tmp/gh_issue_response.json')); print(d.get('html_url','?'))")
  ISSUE_NUM=$(python3 -c "import json; d=json.load(open('/tmp/gh_issue_response.json')); print(d.get('number','?'))")
  echo "✅  Issue #${ISSUE_NUM} erstellt: ${ISSUE_URL}"
else
  echo "⚠️   Issue konnte nicht erstellt werden (HTTP ${HTTP_STATUS}):"
  cat /tmp/gh_issue_response.json
fi
