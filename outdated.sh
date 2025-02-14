#!/bin/bash

set +e

NPM_VERSION=$(npm --version)
npx -y semver -r ">=10.8.1" "$NPM_VERSION"

if [ "$?" != "0" ]; then
  echo "npm version $NPM_VERSION is not supported - must use >=10.8.1"
  exit 1
else
  echo "npm version $NPM_VERSION is supported"
fi

if [ ! -z "$INPUT_PROJECT_PATH" ]; then
  echo "Switching in to $INPUT_PROJECT_PATH to run outdated commands"
  cd $INPUT_PROJECT_PATH

  PROJECT=${INPUT_PROJECT_PATH##*/}
  PROJECT=${PROJECT:-/}
else
  if [ -z "$INPUT_PROJECT" ]; then
    PROJECT=${PWD##*/}
  else
    PROJECT=$INPUT_PROJECT
  fi
fi

if [ -z "$1" ]; then
  if [ ! -z "$GITHUB_OUTPUT" ]; then
    # For testing purposes
    OUTPUT_TARGET="$GITHUB_OUTPUT"
  else
    OUTPUT_TARGET="/dev/stdout"
    echo Output file param was not specified at \$1 and GITHUB_OUTPUT not present, outputting to $OUTPUT_TARGET
  fi
else
  OUTPUT_TARGET=$1
fi

if [ -z "$INPUT_DEPENDENCY" ]; then
    echo "'dependency' must be provided"
    exit 1
else
 # To-do - check input_dep or package as input.
  PACKAGE=$INPUT_DEPENDENCY
fi

if [ "$INPUT_SKIP_NPM_CI_EXECUTE" == "false" ]; then
  npm ci >>/dev/stderr
fi

OUTDATED=$(npm outdated --json)

echo "Checking for updated versions of $PACKAGE on $PROJECT"

if [ -z "$OUTDATED" ] || [ "$OUTDATED" = "{}" ]; then
  echo "hasNewVersion=false" >> "$OUTPUT_TARGET"
  if [ "$INPUT_FAIL_ON_NO_NEW_VERSION" = "true" ]; then
    echo "No new version found for $PACKAGE - ending with error."
    exit 1
  fi
  echo "No new version found for $PACKAGE - ending normally."
  exit 0
fi

PACKAGE_OUTDATED=$(echo "$OUTDATED" | jq -c -r --arg package "$PACKAGE" '
  .[$package] | if type == "array" then . else [.] end
')

if [ "$INPUT_USE_LATEST" = "true" ]; then
  VERSION_DATA=$(echo $PACKAGE_OUTDATED | jq -c -r '
    .[] | .hasNewVersion = (.current != .latest)
  ')
else
  VERSION_DATA=$(echo $PACKAGE_OUTDATED | jq -c -r '
    .[] | .hasNewVersion = (.current != .wanted)
  ')
fi


echo Version data for all dependents on $PACKAGE: $VERSION_DATA

if [ "$INPUT_USE_LATEST" = "true" ]; then
  DEPENDENT_DATA=$(echo $PACKAGE_OUTDATED | jq -c -r --arg project "$PROJECT" '
    .[] | select(.dependent == $project) | .hasNewVersion = (.current != .latest)
  ')
else
  DEPENDENT_DATA=$(echo $PACKAGE_OUTDATED | jq -c -r --arg project "$PROJECT" '
    .[] | select(.dependent == $project) | .hasNewVersion = (.current != .wanted)
  ')
fi
HAS_NEW_VERSION=$(echo $DEPENDENT_DATA | jq -r .hasNewVersion)

VALUES=($(echo $DEPENDENT_DATA | jq -r 'to_entries[] | "\(.key)=\(.value)"'))

echo $OUTPUT >> "$OUTPUT_TARGET"
if [ "$HAS_NEW_VERSION" != "true" ]; then
  echo "No new version found for $PACKAGE after reading $PROJECT's package.json"
  echo "hasNewVersion=false" >> "$OUTPUT_TARGET"
  if [ "$INPUT_FAIL_ON_NO_NEW_VERSION" = "true" ]; then
    exit 1
  fi
  exit 0
fi

echo "Package $PACKAGE@$(echo $DEPENDENT_DATA | jq -r .current) wants $(echo $DEPENDENT_DATA | jq -r .wanted) with $(echo $DEPENDENT_DATA | jq -r .latest) latest available."
for i in "${VALUES[@]}"; do
  echo $i
  echo $i >> "$OUTPUT_TARGET"
done
