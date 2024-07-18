#!/bin/bash
set +e

if [ -z "$INPUT_DEPENDENCY" ]; then
    echo "'dependency' must be provided"
    exit 1
fi  

if [ -z "$INPUT_PROJECT" ]; then
    echo "'project' must be provided"
    exit 1
fi

# if [ -z "$GITHUB_OUTPUT" ]; then
#   # For testing purposes
#   GITHUB_OUTPUT="/dev/stdout"
# fi

if [ "$INPUT_SKIP_NPM_CI_EXECUTE" == "false" ]; then
  npm ci
fi

PACKAGE=$INPUT_DEPENDENCY
OUTDATED=`npm outdated --json --all $PACKAGE`

echo "OUTDATED: $OUTDATED"
echo "Checking $PACKAGE"

if [ -z "$OUTDATED" ] || [ "$OUTDATED" = "{}" ]; then
  echo "No new version found for $PACKAGE"
  echo "hasNewVersion=false" >> "$GITHUB_OUTPUT"
  if [ "$INPUT_FAIL_ON_NO_NEW_VERSION" = "true" ]; then
    exit 1
  fi
  exit 0
fi

PACKAGE_OUTDATED=$(echo "$OUTDATED" | jq -r --arg package "$PACKAGE" '
  .[$package] | if type == "array" then . else [.] end
')

LATEST_VERSION=$(echo $PACKAGE_OUTDATED | jq -r --arg project "$INPUT_PROJECT" '
  .[] | select(.dependent == $project) | .latest
')

WANTED_VERSION=$(echo $PACKAGE_OUTDATED | jq -r --arg project "$INPUT_PROJECT" '
  .[] | select(.dependent == $project) | .wanted
')

CURRENT_VERSION=$(echo $PACKAGE_OUTDATED | jq -r --arg project "$INPUT_PROJECT" '
  .[] | select(.dependent == $project) | .current
')

DEPENDENT_DATA=$(echo $PACKAGE_OUTDATED | jq -r --arg project "$INPUT_PROJECT" '
  .[] | select(.dependent == $project)
')

echo Dep data: $DEPENDENT_DATA

if [ -z "$LATEST_VERSION" ]; then
  echo "No new version found for $PACKAGE"
  echo "hasNewVersion=false" >> "$GITHUB_OUTPUT"
  exit 1
fi

echo "Package $PACKAGE@$CURRENT_VERSION wants $WANTED_VERSION with $LATEST_VERSION latest available."
echo "hasNewVersion=true" >> "$GITHUB_OUTPUT"
echo "wantedVersion=$WANTED_VERSION" >> "$GITHUB_OUTPUT"
echo "latestVersion=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
echo "currentVersion=$CURRENT_VERSION" >> "$GITHUB_OUTPUT"
echo "LATEST_VERSION=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
