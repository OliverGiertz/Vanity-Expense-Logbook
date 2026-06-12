#!/bin/sh
# ci_scripts/ci_post_clone.sh
#
# Xcode Cloud führt dieses Skript direkt nach dem Git-Clone aus,
# bevor der Build startet. Hier werden Abhängigkeiten vorbereitet.

set -e

echo "ci_post_clone: Vorbereitung …"

# Bundler / Fastlane (falls Gemfile vorhanden)
if [ -f "$CI_WORKSPACE/Gemfile" ]; then
  echo "  → Installiere Ruby Gems …"
  cd "$CI_WORKSPACE"
  bundle install --quiet
fi

echo "ci_post_clone: Fertig."
