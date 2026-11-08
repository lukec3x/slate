# Releasing Slate

A closed version is a `release/<marketing-version>` branch, a tag on the commit that was archived, and a GitHub Release on that tag. `main` stays shippable and keeps moving. Product work does not land on the release branch.

The marketing version in the project is `MARKETING_VERSION` (today `1.0`). The build number is `CURRENT_PROJECT_VERSION` (today `1`). The tag matches the marketing version: `v1.0`.

## What stays manual

These decisions and accounts cannot be derived from the repo:

- Choosing the marketing version and cutting `release/<marketing-version>` from `main`.
- Deciding that the branch is done. Only bug fixes and the version bump land there.
- Writing the release notes. A workflow can draft them from commits; the text that ships is reviewed by hand.
- The Apple Developer session on this Mac: team `C92HDA557M`, automatic signing, and the archive uploaded to TestFlight or the App Store. iPhone, iPad, and visionOS builds install through TestFlight or the App Store. An `.ipa` attached to a GitHub Release does not install on those devices.
- The App Store Connect record for `br.dev.lucasandrade.Slate`: the first creation, export compliance, age rating, and privacy details.
- `Slate/Secrets.plist`. It is gitignored. If it is present when Xcode archives, the TMDB read access token is copied into the app bundle. A binary uploaded to GitHub is archived without that file. The copy you send to TestFlight for yourself may include it.

One-time setup, only if a workflow later uploads a Mac build or a TestFlight build:

- An App Store Connect API key (issuer ID, key ID, and the `.p8` file).
- A distribution certificate and its private key, exported as a `.p12`, plus the provisioning profiles if signing is switched from automatic to manual for the runner.
- Those files stored as GitHub Actions secrets, not committed.
- A GitHub-hosted macOS runner whose Xcode includes the iOS 27.2, macOS 26.7, and visionOS 27.2 SDKs. If the runner image does not, the archive stays on this Mac.

## What can be automated

Pushing the tag is the trigger. A workflow at `.github/workflows/release.yml` then:

1. Checks out the tagged commit.
2. Runs `SlateTests` with `xcodebuild test`. Those tests do not use the network.
3. Creates the GitHub Release with `gh release create`, using the tag name as the title and the commits since the previous tag as the notes.
4. Leaves GitHub's automatic source `.zip` and `.tar.gz` on the Release.

That workflow needs no Apple credential. It publishes the closed source. It does not produce an installable iPhone, iPad, or visionOS build.

A later job on the same tag can archive the Mac app, notarize it, and upload a `.zip` of `Slate.app` to that Release. That job needs the secrets above, a temporary keychain for the certificate, `xcodebuild archive` for `generic/platform=macOS`, and `notarytool`. The archive step runs without `Slate/Secrets.plist`, so the published Mac app asks for the TMDB token the same way a fresh checkout does.

Uploading an iOS or visionOS archive to TestFlight can use the same API key and `xcodebuild -exportArchive`. That upload is separate from the GitHub Release assets. The workflow in this repo is not added until the runner image and the secrets exist.

## Close a version

Examples below use marketing version `1.0` and build `1`. Replace them with the version you are closing. Bump the build number on every archive, including a second archive of the same marketing version.

### 1. Cut the branch

```sh
git checkout main
git pull
git checkout -b release/1.0
```

### 2. Stabilize

Fix only what blocks this version. Commit on `release/1.0`.

### 3. Set the version

In `Slate.xcodeproj/project.xcproj`, set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` on the Slate, SlateTests, and SlateUITests targets. Keep the three targets on the same pair of numbers.

`MARKETING_VERSION` changes only on `release/*` or `hotfix/*`.

### 4. Commit the version

```sh
git commit -am "$(cat <<'EOF'
Set the version to 1.0 (1)

This is the marketing version and build number of the archive
submitted for this release.
EOF
)"
```

### 5. Tag that commit

The tag points at the version commit, before `main` receives later work.

```sh
git tag v1.0
```

### 6. Archive on this Mac

Open `Slate.xcodeproj` and select the `Slate` scheme.

- iPhone, iPad, and visionOS: Product → Archive, then Distribute App to App Store Connect. Install from TestFlight.
- Mac, when you want a file on the GitHub Release: archive for macOS from a checkout that has no `Slate/Secrets.plist`, export with Developer ID, notarize, and staple. Zip the notarized `Slate.app`.

Each new archive of this marketing version gets a new `CURRENT_PROJECT_VERSION`, committed on the release branch before you archive again. The tag stays on the commit you submitted. A replacement build of the same marketing version is a new build number, not a new tag, until the marketing version itself changes.

### 7. Merge back

```sh
git checkout main
git merge --no-ff release/1.0
git push origin main
git push origin v1.0
git push origin release/1.0
```

Pushing `v1.0` is what a release workflow listens for. Until that workflow exists, create the Release in the next step.

### 8. Publish the GitHub Release

```sh
gh release create v1.0 \
  --title "1.0" \
  --notes "$(cat <<'EOF'
## Summary

- What this version changes.

EOF
)"
```

Add a notarized Mac zip only when you have one built without the TMDB token:

```sh
gh release upload v1.0 Slate-1.0-macOS.zip
```

Do not upload an `.ipa`, a provisioning profile, or `Secrets.plist`.

After the tag workflow exists, this step is the workflow. You still read the generated notes and edit them with `gh release edit v1.0` when the commit list is not the description you want.

## Hotfix

When `main` has already moved past a shipped tag:

```sh
git checkout -b hotfix/1.0.1 v1.0
```

Bump `MARKETING_VERSION` to `1.0.1` and `CURRENT_PROJECT_VERSION` to the next build. Commit the fix and the version, tag `v1.0.1`, archive, merge the hotfix branch into `main`, and push the tag. Publish the GitHub Release from `v1.0.1` the same way.
