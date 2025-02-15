#!/bin/bash -euo pipefail

# Get the current version from Xcode project
xcode_version=$(xcodebuild -showBuildSettings | grep MARKETING_VERSION | tr -d "MARKETING_VERSION = ")

# Check if the current git commit hash has a matching tag
if [ -z "$(git tag --list "v$xcode_version")" ]; then
  echo "No matching git tag found for version $xcode_version. Creating a new tag."
  git tag -a "v$xcode_version" -m "Version $xcode_version"
else
  echo "Git tag for version $xcode_version already exists."
fi
