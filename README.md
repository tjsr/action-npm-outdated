# action-npm-outdated

A github action to return the latest version available and requested by a dependency in an npm package

## Why?

What I want to achieve with this and a group of other github actions is a worflow where:

- For any branch, GHA will not just build that branch, but publish a prerelease version of the package with the branch name then;
- For every project known to use it as a dependency, run a webhook which would update that project to create a branch that uses the new version, and run tests against it.
- When it merged to master, automatically raise a PR to enable that new version to be merged to main.

While none of these steps rely on this github action, this GHA would be the first one that likely kicks off that chain of events, by updating a dependency via a workflow, raising the PR, which can then be merged and auto-published, then causing the same again upgstream.

## Requirements

This action requires npm v10.8.1 or v10.8.2, as the JSON report format it reads and parses is different in 10.8.0 and before.  At the time of writing it checks these exact versions - a later update will be required when 10.9.x is released.

## Usage

Use this action to manually get the latest available or wanted version of an artifact within a project.  That value can then be used to call an `npm install...` command from an action or workflow.  The typical use-case for this would be to then generate a PR from that upgrade call - this could be triggered manually, from the result of another build, a push, or a PR merge.

### Dependencies

Before calling this script, you must have installed all NPM dependencies for the project.

eg,

```yaml
- name: Check out repository code
  uses: actions/checkout@v4

# Setup .npmrc file to publish to GitHub Packages
- uses: actions/setup-node@v4
  with:
    node-version: 20.15.1
    registry-url: 'https://npm.pkg.github.com'

- name: Install npm 10.8.2
  run: npm install -g npm@10.8.2

- name: Cache node modules
  id: cache-npm
  uses: actions/cache@main
  env:
    cache-name: cache-node-modules
  with:
    # npm cache files are stored in `~/.npm` on Linux/macOS
    path: ~/.npm
    # todo - change this so we are less restrictive on package-lock changes
    key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-build-${{ env.cache-name }}-
      ${{ runner.os }}-build-
      ${{ runner.os }}-

- name: Install ${{ env.PROJECT }} dependencies
  id: install
  run: npm ci

- name: Get latest version for ${{ env.PACKAGE }} on ${{ env.PROJECT }}
  id: get-latest-version
  uses: tjsr/action-npm-outdated@main
  with:
    project: ${{ env.PROJECT }}
    dependency: ${{ env.PACKAGE }}
```

In the example above, `env.PROJECT` is the name of the npm artifact in the owning package.json file, and `env.PACKAGE` is the target package to search for and retrieve the `outdated` data for.

### Options

Values which can be passed to `tjsr/action-npm-outdated` are:

```yaml
  dependency:
    description: 'Dependency to check'
    required: true
  project:
    description: 'The target project name that must be the owner of the package'
    required: false
  failOnNoNewVersion:
    description: 'Whether the build should fail with an exit code if no new version is available for the specified package'
    required: false
    default: false
  skipNpmCiExecute:
    description: 'Whether to skip the npm ci command execution being called implicitly'
    required: false
    default: true
  projectPath:
    description: 'The path to the project to run npm-related scripts within'
    required: false
```

`dependency` is the name of the target artifact you want to update to the latest version.
Use the `projectPath` value if your npm project does not live in the base directoy of your repo you're calling the github action - for example if you're building modules or in a monorepo.

The output of this call can then be passed to other commands, for example:

```yaml
  - name: Update ${{ env.PACKAGE }} via npm
    if: steps.get-latest-version.outputs.hasNewVersion == 'true'
    id: update-package
    run: |
      npm install --save-exact ${{ env.PACKAGE }}@${{ steps.get-latest-version.outputs.latest }}
```

### Advanced usage

If you wanted to update multiple dependencies in a single action, you could potentially build this step in to a matrix.

## To-Do items

1. Add ability to only updated to 'wanted' rather than 'latest' version.
2. Output results as a JSON object array to enable checking multiple dependencies in a single call.
