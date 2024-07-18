#!/bin/bash
set +e

if [ -z "$1" ]; then
  if [ ! -z "$GITHUB_OUTPUT" ]; then
    # For testing purposes
    OUTPUT_TARGET="$GITHUB_OUTPUT"
  else
    OUTPUT_TARGET="/dev/stdout"
    echo Output file param was not specified at \$1 and GITHUB_OUTPUT not present, outputting to $OUTPUT_TARGET
  fi
else
  OUTPUT_FILE=$1
fi

if [ -z "$INPUT_DEPENDENCY" ]; then
    >&2 echo "'dependency' must be provided"
    exit 1
else
 # To-do - check input_dep or package as input.
  PACKAGE=$INPUT_DEPENDENCY
fi

if [ -z "$INPUT_PROJECT" ]; then
    >&2 echo "'project' must be provided"
    exit 1
fi


if [ "$INPUT_SKIP_NPM_CI_EXECUTE" == "false" ]; then
  npm ci >>/dev/stderr
fi

OUTDATED=`npm outdated --json --all $PACKAGE`

echo "Checking for updated versions of $PACKAGE on $INPUT_PROJECT"

if [ -z "$OUTDATED" ] || [ "$OUTDATED" = "{}" ]; then
  echo "No new version found for $PACKAGE"
  echo "hasNewVersion=false" >> "$OUTPUT_FILE"
  if [ "$INPUT_FAIL_ON_NO_NEW_VERSION" = "true" ]; then
    exit 1
  fi
  exit 0
fi

PACKAGE_OUTDATED=$(echo "$OUTDATED" | jq -c -r --arg package "$PACKAGE" '
  .[$package] | if type == "array" then . else [.] end
')

# LATEST_VERSION=$(echo $PACKAGE_OUTDATED | jq -r --arg project "$INPUT_PROJECT" '
#   .[] | select(.dependent == $project) | .latest
# ')

# WANTED_VERSION=$(echo $PACKAGE_OUTDATED | jq -r --arg project "$INPUT_PROJECT" '
#   .[] | select(.dependent == $project) | .wanted
# ')

# CURRENT_VERSION=$(echo $PACKAGE_OUTDATED | jq -r --arg project "$INPUT_PROJECT" '
#   .[] | select(.dependent == $project) | .current
# ')

DEPENDENT_DATA=$(echo $PACKAGE_OUTDATED | jq -c -r --arg project "$INPUT_PROJECT" '
  .[] | select(.dependent == $project) | .hasNewVersion = (.current != .latest)
')

echo "$DEPENDENT_DATA" | jq -r 'to_entries[] | "\(.key)=\(.value)"' >> "$OUTPUT_FILE"
if [ "$(echo $DEPENDENT_DATA | jq -r .hasNewVersion)" != "true" ]; then
  echo "No new version found for $PACKAGE"
  if [ "$INPUT_FAIL_ON_NO_NEW_VERSION" = "true" ]; then
    exit 1
  fi
  exit 0
fi

echo "Package $PACKAGE@$(echo $DEPENDENT_DATA | jq -r .current) wants $(echo $DEPENDENT_DATA | jq -r .wanted) with $(echo $DEPENDENT_DATA | jq -r .latest) latest available."
