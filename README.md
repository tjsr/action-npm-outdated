# action-npm-outdated

A github action to return the latest version available and requested by a dependency in an npm package

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
          scope: '@tjsr'

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

## Options

Values which can be passed to `tjsr/action-npm-outdated` are:

```yaml
  dependency:
    description: 'Dependency to check'
    required: false
  project:
    description: 'The target project name that must be the owner of the package'
    required: true
  failOnNoNewVersion:
    description: 'Whether the build should fail with an exit code if no new version is available for the specified package'
    required: false
    default: false
  skipNpmCiExecute:
    description: 'Whether to skip the npm ci command execution being called implicitly'
    required: false
    default: true
```

The output of this call can then be passed to other commands, for example:

```yaml
  - name: Update ${{ env.PACKAGE }} via npm
    if: steps.get-latest-version.outputs.hasNewVersion == 'true'
    id: update-package
    run: |
      npm install --save-exact ${{ env.PACKAGE }}@${{ steps.get-latest-version.outputs.latest }}
```
