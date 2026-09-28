# Releasing

Releases are cut from `main` with:

```sh
scripts/release.sh 0.8.0
```

The script bumps `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in the Xcode project, commits `Release 0.8.0`, tags `0.8.0` and pushes. The tag triggers the [Release workflow](.github/workflows/release.yml), which:

1. checks that the tag matches the project version,
2. runs the tests,
3. archives the app with the hardened runtime,
4. signs it with a Developer ID certificate,
5. notarizes it with Apple and staples the ticket,
6. publishes `dmenu-mac.zip` (plus its sha256) as a GitHub release with generated notes.

## Dry run

To exercise the whole pipeline without publishing anything, run the workflow by hand on any branch:

```sh
gh workflow run release.yml --ref my-branch
```

It builds, signs and notarizes exactly like a tag does, but uploads `dmenu-mac.zip` as a workflow artifact instead of creating a release. Only `main` can use the signing secrets, so run it from `main` to test the signed path. Pull requests that touch the release files (the workflow, `scripts/`, the entitlements, `Info.plist`) get the same dry run automatically, without secrets, which exercises the ad-hoc path.

## Signing secrets

Signing and notarization need these secrets in the `release` [environment](https://github.com/oNaiPs/dmenu-mac/settings/environments), which only version tags and `main` are allowed to use. Set them with `gh secret set NAME --env release`. Without them the workflow still publishes an ad-hoc signed build, but as a pre-release, since Gatekeeper and Homebrew reject it.

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | `base64 -i cert.p12` of the "Developer ID Application" certificate exported from Keychain Access |
| `MACOS_CERTIFICATE_PASSWORD` | password used when exporting the .p12 |
| `APPLE_TEAM_ID` | the 10-character team id from [developer.apple.com](https://developer.apple.com/account) |
| `APP_STORE_CONNECT_KEY_ID` | key id of an [App Store Connect API key](https://appstoreconnect.apple.com/access/integrations/api) with the Developer role |
| `APP_STORE_CONNECT_ISSUER_ID` | issuer id shown on the same page |
| `APP_STORE_CONNECT_API_KEY` | `base64 -i AuthKey_XXXX.p8` |

## Homebrew

After the release is published, update the cask:

```sh
brew bump-cask-pr dmenu-mac --version 0.8.0
```
