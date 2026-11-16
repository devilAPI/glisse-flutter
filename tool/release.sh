#!/usr/bin/env bash
# Starts a release: tool/release.sh 0.3.1
#
# Checks that CHANGELOG.md has a "## 0.3.1" section and the tree is clean,
# sets pubspec.yaml's version, runs the checks CI runs, then commits, tags
# v0.3.1 and pushes both. The Release workflow takes it from there: it
# builds the gallery, creates the GitHub release and, once enabled,
# publishes to pub.dev.
set -euo pipefail

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+].+)?$ ]]; then
  echo "Usage: tool/release.sh <version>, such as tool/release.sh 0.3.1" >&2
  exit 64
fi
cd "$(dirname "$0")/.."

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash your changes first." >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/v$version" > /dev/null; then
  echo "The tag v$version already exists." >&2
  exit 1
fi
if ! grep -q "^## $version\$" CHANGELOG.md; then
  echo "Add a '## $version' section to CHANGELOG.md first." >&2
  exit 1
fi

sed -i.bak "s/^version: .*/version: $version/" pubspec.yaml && rm pubspec.yaml.bak

flutter pub get > /dev/null
dart format --output=none --set-exit-if-changed --line-length 120 lib test example/lib example/integration_test
flutter analyze
flutter test

# pub warns about uncommitted files, so commit the version before the dry run.
(cd example && flutter pub get > /dev/null)
git add pubspec.yaml example/pubspec.lock
git diff --cached --quiet || git commit -m "Release $version"
flutter pub publish --dry-run
git tag -a "v$version" -m "glisse_flutter $version"
git push origin HEAD "v$version"
echo "Pushed v$version. Follow the release under the repository's Actions tab."
