#
//  sync_git_build.sh
//  CamperLogBook
//
//  Created by Oliver Giertz on 15.02.25.
//


#!/bin/bash -euo pipefail

export GIT_DIR="$SRCROOT/.git"
COMMIT=$( git rev-parse --short=7 HEAD )

# decimalized git hash is guaranteed to be 10 characters or fewer because
# the biggest short=7 git hash we can get is FFFFFFF and
# printf "%d" 0xFFFFFFF | wc -c. # returns "10"
DECIMALIZED_GIT_COMMIT=$( printf "%d" 0x${COMMIT} )

# Adding --match 'v*.*.*' forces git to look for tags with a version spec, skipping over
# other tags used for eg marking branches
COMMIT_COUNT="$( git describe --tags --match 'v*.*.*' | cut -d - -f 2 -s )"
COMMIT_COUNT=$(( COMMIT_COUNT + 1 ))

# Divide the decimal into two parts for readability
# We don't want the second part (after the inserted period) to start with a zero since Apple will edit that out
# So search for a good place to split the decimal. Note, this will soft-fail if there's five zeros in a row
# In that case, no decimical point is inserted and you get a (still valid) bundle version dd.xxxxxxxxx
SEPARATED_DECIMALIZED_COMMIT="$( echo ${DECIMALIZED_GIT_COMMIT} | sed -E 's/^(.*)([1-9].{4,7})$/\1.\2/' )"

BUNDLE_VERSION="${COMMIT_COUNT}"."${SEPARATED_DECIMALIZED_COMMIT}"

# Override the bundle version in our compiled Info.plist
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $BUNDLE_VERSION" "$CODESIGNING_FOLDER_PATH/Info.plist" ||
  /usr/libexec/PlistBuddy -c "Add CFBundleVersion string $BUNDLE_VERSION" "$CODESIGNING_FOLDER_PATH/Info.plist"

echo "Set Bundle version $BUNDLE_VERSION"