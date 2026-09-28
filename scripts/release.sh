#!/usr/bin/env bash
#
# Cut a release: bump the version in the Xcode project, commit, tag and push.
# The Release workflow (.github/workflows/release.yml) then builds, signs,
# notarizes and publishes the GitHub release from the tag. See RELEASING.md.
#
# Usage: scripts/release.sh X.Y.Z [-y]

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

version="${1:-}"
assume_yes="${2:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: $0 X.Y.Z [-y]"

cd "$(dirname "$0")/.."
pbxproj="dmenu-mac.xcodeproj/project.pbxproj"

branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$branch" == "main" ]] || die "releases are cut from main (currently on $branch)"
[[ -z "$(git status --porcelain)" ]] || die "working tree is not clean"

git fetch --quiet origin main --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main is not in sync with origin/main"
if git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
  die "tag $version already exists"
fi

current="$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' "$pbxproj" | head -1)"
[[ -n "$current" ]] || die "MARKETING_VERSION not found in $pbxproj"
[[ "$current" != "$version" ]] || die "project is already at $version"

grep -q "^## $version\$" CHANGELOG.md \
  || die "CHANGELOG.md has no \"## $version\" section; write the release notes first"

echo "Release $current -> $version"
echo
echo "== CHANGELOG.md"
awk -v v="$version" '/^## / { on = ($2 == v); next } on { print }' CHANGELOG.md
echo "== commits"
git log --oneline "$current..HEAD" 2>/dev/null || git log --oneline -10
echo
if [[ "$assume_yes" != "-y" ]]; then
  read -r -p "Commit, tag $version and push to origin? [y/N] " answer
  [[ "$answer" == [yY] ]] || die "aborted"
fi

sed -i '' -E "s/(MARKETING_VERSION|CURRENT_PROJECT_VERSION) = [0-9.]+;/\1 = $version;/g" "$pbxproj"
git add "$pbxproj"
git commit --quiet -m "Release $version"
git tag -a "$version" -m "dmenu-mac $version"
git push origin main "$version"

echo
echo "Pushed. Follow the build at https://github.com/oNaiPs/dmenu-mac/actions/workflows/release.yml"
