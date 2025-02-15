#
//  hash-from-bundleversion.sh
//  CamperLogBook
//
//  Created by Oliver Giertz on 15.02.25.
//


#!/bin/bash -euo pipefail

if [ ${#} -eq 0 ]
then
# read from STDIN
MAYBE_CFBUNDLEVERSION=$( cat )
else
MAYBE_CFBUNDLEVERSION="${1}"
fi

MAYBE_DECIMALIZED_GIT_HASH=$( echo "${MAYBE_CFBUNDLEVERSION}" | sed -E 's/[[:digit:]]+\.([[:digit:]]+)\.?([[:digit:]]+)?/\1\2/' )

DECIMALIZED_GIT_HASH=$( echo "${MAYBE_DECIMALIZED_GIT_HASH}" | egrep "^[[:digit:]]+$" ) || {
echo "\"${MAYBE_CFBUNDLEVERSION}\" doesnt look like a CFBundleVersion we expect. It should contain two or three dot-separated numbers." >&2
exit 1
}

# convert to hex
GIT_HASH=$( printf "%07x" "${DECIMALIZED_GIT_HASH}" )

echo "${GIT_HASH}"