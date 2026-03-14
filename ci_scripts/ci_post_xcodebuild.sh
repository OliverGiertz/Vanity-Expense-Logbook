#!/bin/sh
# ci_scripts/ci_post_xcodebuild.sh
#
# Xcode Cloud führt dieses Skript nach jeder Action aus.
# Bei Fehlern wird automatisch ein detailliertes GitHub Issue angelegt,
# das alle Informationen für manuelle und automatisierte Verarbeitung enthält.
#
# Benötigte Secrets (Xcode Cloud → Workflow → Environment → Secrets):
#   GITHUB_TOKEN  →  Personal Access Token mit Scope "repo"

set -e

# ── Nur bei Fehler aktiv werden ───────────────────────────────────────────────
if [ "${CI_XCODEBUILD_EXIT_CODE:-0}" = "0" ]; then
  echo "✅  Action '${CI_XCODEBUILD_ACTION}' erfolgreich – kein Issue wird angelegt."
  exit 0
fi

echo "❌  Action '${CI_XCODEBUILD_ACTION}' fehlgeschlagen (Exit-Code: ${CI_XCODEBUILD_EXIT_CODE})"

# ── Pflichtfeld prüfen ────────────────────────────────────────────────────────
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "⚠️   GITHUB_TOKEN nicht gesetzt – Issue wird nicht erstellt."
  echo "     Bitte in Xcode Cloud → Workflow → Environment → Secrets eintragen."
  exit 0
fi

# ── Metadaten zusammenstellen ─────────────────────────────────────────────────
REPO="OliverGiertz/Vanity-Expense-Logbook"
BRANCH="${CI_BRANCH:-unbekannt}"
COMMIT_FULL="${CI_COMMIT:-unbekannt}"
COMMIT_SHORT=$(echo "$COMMIT_FULL" | cut -c1-7)
BUILD_NUM="${CI_BUILD_NUMBER:-?}"
WORKFLOW="${CI_WORKFLOW:-?}"
ACTION="${CI_XCODEBUILD_ACTION:-?}"
EXIT_CODE="${CI_XCODEBUILD_EXIT_CODE:-?}"
PRODUCT="${CI_PRODUCT:-CamperLogBook}"
BUNDLE_ID="${CI_BUNDLE_ID:-VanityOnTour.CamperLogBook}"
TEAM_ID="${CI_TEAM_ID:-T5A3ZR4938}"
DATE_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
DATE_HUMAN=$(date '+%d.%m.%Y %H:%M UTC')

# Version + Build aus project.pbxproj lesen
PBXPROJ="$CI_WORKSPACE/CamperLogBook.xcodeproj/project.pbxproj"
VERSION=$(grep 'MARKETING_VERSION' "$PBXPROJ" 2>/dev/null \
  | grep -v '= 1;' | head -1 | tr -d ' ;' | cut -d= -f2 || echo "?")
BUILD_VERSION=$(grep 'CURRENT_PROJECT_VERSION' "$PBXPROJ" 2>/dev/null \
  | grep -v '= 1;' | head -1 | tr -d ' ;' | cut -d= -f2 || echo "?")

# Action-Label für Issue-Titel
case "$ACTION" in
  test)    ACTION_EMOJI="🧪"; ACTION_LABEL="Test-Fehler"   ;;
  archive) ACTION_EMOJI="📦"; ACTION_LABEL="Archive-Fehler" ;;
  analyze) ACTION_EMOJI="🔍"; ACTION_LABEL="Analyse-Fehler" ;;
  build)   ACTION_EMOJI="🔨"; ACTION_LABEL="Build-Fehler"   ;;
  *)       ACTION_EMOJI="❌"; ACTION_LABEL="CI-Fehler"       ;;
esac

# ── Test-Ergebnisse aus .xcresult extrahieren (nur bei test-Action) ───────────
TEST_SUMMARY=""
FAILED_TESTS_LIST=""

if [ "$ACTION" = "test" ] && [ -n "${CI_RESULT_BUNDLE_PATH:-}" ] && [ -d "$CI_RESULT_BUNDLE_PATH" ]; then
  echo "  → Lese Test-Ergebnisse aus: $CI_RESULT_BUNDLE_PATH"

  # Fehlgeschlagene Tests über xcresulttool extrahieren
  FAILED_TESTS_LIST=$(xcrun xcresulttool get \
    --format json \
    --path "$CI_RESULT_BUNDLE_PATH" 2>/dev/null \
    | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    actions = data.get('actions', {}).get('_values', [])
    failures = []
    for action in actions:
        result = action.get('actionResult', {})
        tests = result.get('testsRef', {})
        summary = result.get('testSummaries', {}).get('_values', [])
        for s in summary:
            for tg in s.get('testableSummaries', {}).get('_values', []):
                suite_name = tg.get('targetName', {}).get('_value', '?')
                for ts in tg.get('tests', {}).get('_values', []):
                    for tc in ts.get('subtests', {}).get('_values', []):
                        for t in tc.get('subtests', {}).get('_values', []):
                            status = t.get('testStatus', {}).get('_value', '')
                            if status == 'Failure':
                                name = t.get('identifier', {}).get('_value', '?')
                                dur  = t.get('duration', {}).get('_value', '?')
                                failures.append(f'- \`{name}\` ({dur}s)')
    print('\n'.join(failures) if failures else '')
except Exception as e:
    print('')
" 2>/dev/null || true)

  if [ -n "$FAILED_TESTS_LIST" ]; then
    TEST_COUNT=$(echo "$FAILED_TESTS_LIST" | grep -c '^-' || echo "?")
    TEST_SUMMARY="### 🔴 Fehlgeschlagene Tests (${TEST_COUNT})

${FAILED_TESTS_LIST}"
  else
    TEST_SUMMARY="### 🔴 Test-Ergebnisse

Fehlgeschlagene Tests konnten nicht automatisch extrahiert werden.
Bitte Build **#${BUILD_NUM}** in App Store Connect → Xcode Cloud einsehen."
  fi
fi

# ── Commit-Log für Kontext ────────────────────────────────────────────────────
RECENT_COMMITS=$(git -C "$CI_WORKSPACE" log --oneline -5 2>/dev/null \
  | sed 's/^/- /' || echo "- (nicht verfügbar)")

# ── App Store Connect Link ────────────────────────────────────────────────────
ASC_BUILDS_URL="https://appstoreconnect.apple.com/teams/${TEAM_ID}/apps"
XCODE_CLOUD_URL="https://appstoreconnect.apple.com/teams/${TEAM_ID}/frameworks/${BUNDLE_ID}/builds"

# ── Issue-Titel ───────────────────────────────────────────────────────────────
TITLE="${ACTION_EMOJI} [Xcode Cloud] ${ACTION_LABEL} v${VERSION} – ${DATE_HUMAN} (${BRANCH}@${COMMIT_SHORT})"

# ── Issue-Body ────────────────────────────────────────────────────────────────
BODY=$(cat <<EOF
## ${ACTION_EMOJI} ${ACTION_LABEL} in Xcode Cloud

| Feld | Wert |
|---|---|
| **App-Version** | v${VERSION} (Build ${BUILD_VERSION}) |
| **Branch** | \`${BRANCH}\` |
| **Commit** | [\`${COMMIT_SHORT}\`](https://github.com/${REPO}/commit/${COMMIT_FULL}) |
| **Xcode Cloud Build** | #${BUILD_NUM} |
| **Workflow** | ${WORKFLOW} |
| **Action** | \`${ACTION}\` (Exit-Code: ${EXIT_CODE}) |
| **Datum** | ${DATE_HUMAN} |
| **Bundle ID** | \`${BUNDLE_ID}\` |

## 🔗 Direkte Links

- [Xcode Cloud Build #${BUILD_NUM} ansehen](${XCODE_CLOUD_URL})
- [App Store Connect → Xcode Cloud](${ASC_BUILDS_URL})
- [Commit ${COMMIT_SHORT} auf GitHub](https://github.com/${REPO}/commit/${COMMIT_FULL})
- [Branch \`${BRANCH}\` auf GitHub](https://github.com/${REPO}/tree/${BRANCH})

${TEST_SUMMARY}

## 📋 Letzte Commits auf Branch \`${BRANCH}\`

${RECENT_COMMITS}

## 🤖 Automatisierte Verarbeitung

\`\`\`yaml
# Maschinenlesbare Metadaten für Claude / Automatisierung
ci_failure:
  action: "${ACTION}"
  exit_code: "${EXIT_CODE}"
  version: "${VERSION}"
  build_version: "${BUILD_VERSION}"
  branch: "${BRANCH}"
  commit: "${COMMIT_FULL}"
  build_number: "${BUILD_NUM}"
  workflow: "${WORKFLOW}"
  bundle_id: "${BUNDLE_ID}"
  team_id: "${TEAM_ID}"
  timestamp_iso: "${DATE_ISO}"
  xcode_cloud_builds_url: "${XCODE_CLOUD_URL}"
  repo: "${REPO}"
\`\`\`

## 🛠 Nächster Schritt für Claude

Dieses Issue Claude zur automatischen Behebung übergeben:

1. Issue öffnen (du bist gerade hier)
2. Fehlerlog aus [Xcode Cloud Build #${BUILD_NUM}](${XCODE_CLOUD_URL}) kopieren
3. Claude beauftragen:

> *"Bitte behebe den Fehler aus Issue #[NUMMER]. Die Fehlerdetails aus dem Xcode Cloud Log sind: [LOG EINFÜGEN]"*

---
*Automatisch erstellt von \`ci_scripts/ci_post_xcodebuild.sh\` – Workflow: ${WORKFLOW} – Build #${BUILD_NUM}*
EOF
)

# ── Labels bestimmen ──────────────────────────────────────────────────────────
case "$ACTION" in
  test)    LABELS='["bug","ci-failure","test-failure"]' ;;
  archive) LABELS='["bug","ci-failure","archive-failure"]' ;;
  *)       LABELS='["bug","ci-failure"]' ;;
esac

# ── GitHub Issue via API anlegen ──────────────────────────────────────────────
echo "  → Lege GitHub Issue an …"

HTTP_STATUS=$(curl -s -o /tmp/gh_issue_response.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${REPO}/issues" \
  --data "{
    \"title\": $(echo "$TITLE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'),
    \"body\":  $(echo "$BODY"  | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'),
    \"labels\": ${LABELS}
  }")

if [ "$HTTP_STATUS" = "201" ]; then
  ISSUE_URL=$(python3 -c "import json; d=json.load(open('/tmp/gh_issue_response.json')); print(d.get('html_url','?'))")
  ISSUE_NUM=$(python3 -c "import json; d=json.load(open('/tmp/gh_issue_response.json')); print(d.get('number','?'))")
  echo "✅  Issue #${ISSUE_NUM} erstellt: ${ISSUE_URL}"
else
  echo "⚠️   Issue konnte nicht erstellt werden (HTTP ${HTTP_STATUS}):"
  cat /tmp/gh_issue_response.json
fi
