#!/usr/bin/env bash
set -euo pipefail

# scripts/bump_version.sh <new-version>
#
#   ./scripts/bump_version.sh 1.28
#
# Single-step release version bump. Updates MARKETING_VERSION and
# CURRENT_PROJECT_VERSION in project.pbxproj (the PapaDot app + widget
# extension targets only — test targets stay at Xcode's default 1.0/1),
# keeps the README badge in sync, commits, and tags the commit.
#
# Run this LAST, after CHANGELOG.md already documents the new version —
# the script refuses to run otherwise. This exists because MARKETING_VERSION
# drifted 3 releases behind CHANGELOG.md/git history before (1.24 in Xcode
# while CHANGELOG/commits had moved on to 1.27): the changelog and commit
# message were updated by hand each time, but nothing forced the Xcode
# project file to move with them.
#
# CURRENT_PROJECT_VERSION follows this project's established YYYYMMDD
# build-number convention (confirmed from project history back to v1.1).
# If that convention ever changes, update the regex below accordingly.
#
# This script commits and tags locally but never pushes — push is a
# separate, deliberate step:
#   git push origin main --tags

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PBXPROJ="PapaDot.xcodeproj/project.pbxproj"
CHANGELOG="CHANGELOG.md"
README="README.md"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <new-version>   e.g. $0 1.28" >&2
  exit 1
fi

NEW_VERSION="$1"
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must look like X.Y (e.g. 1.28), got '$NEW_VERSION'" >&2
  exit 1
fi

TAG="v$NEW_VERSION"
BUILD_DATE="$(date +%Y%m%d)"

# Real (non-test-target) MARKETING_VERSION values should always be identical
# across the app + widget targets. If they've diverged, something else is
# wrong — fix that by hand before bumping further.
CURRENT_VERSIONS="$(grep -oE 'MARKETING_VERSION = [0-9]+\.[0-9]+;' "$PBXPROJ" \
  | sed -E 's/MARKETING_VERSION = ([0-9.]+);/\1/' | sort -u | grep -v '^1\.0$' || true)"
CURRENT_VERSION_COUNT="$(echo -n "$CURRENT_VERSIONS" | grep -c . || true)"

if [ "$CURRENT_VERSION_COUNT" -eq 0 ]; then
  echo "Error: could not find any non-default MARKETING_VERSION in $PBXPROJ" >&2
  exit 1
elif [ "$CURRENT_VERSION_COUNT" -gt 1 ]; then
  echo "Error: app/widget targets already disagree on MARKETING_VERSION — fix by hand first:" >&2
  echo "$CURRENT_VERSIONS" >&2
  exit 1
fi
CURRENT_VERSION="$CURRENT_VERSIONS"

if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
  echo "Error: MARKETING_VERSION is already $CURRENT_VERSION — nothing to bump." >&2
  exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Error: tag $TAG already exists." >&2
  exit 1
fi

# Refuse to sweep unrelated in-progress work into the release commit — only
# the three files this script itself touches may be dirty.
DIRTY="$(git status --porcelain -- . ":(exclude)$PBXPROJ" ":(exclude)$CHANGELOG" ":(exclude)$README")"
if [ -n "$DIRTY" ]; then
  echo "Error: uncommitted changes outside pbxproj/CHANGELOG/README — commit or stash them first:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

if ! grep -q "## Version $NEW_VERSION" "$CHANGELOG"; then
  echo "Error: $CHANGELOG has no '## Version $NEW_VERSION' entry yet." >&2
  echo "Add release notes for $NEW_VERSION to $CHANGELOG before bumping." >&2
  exit 1
fi

echo "Bumping MARKETING_VERSION $CURRENT_VERSION -> $NEW_VERSION, CURRENT_PROJECT_VERSION -> $BUILD_DATE"

python3 - "$PBXPROJ" "$CURRENT_VERSION" "$NEW_VERSION" "$BUILD_DATE" <<'PYEOF'
import re, sys
path, current, new, build_date = sys.argv[1:5]
with open(path) as f:
    content = f.read()

marketing_pattern = f"MARKETING_VERSION = {re.escape(current)};"
count_marketing = content.count(marketing_pattern)
if count_marketing == 0:
    sys.exit(f"Could not find any 'MARKETING_VERSION = {current};' in {path}")
content = content.replace(marketing_pattern, f"MARKETING_VERSION = {new};")

# Only touches build numbers that already look like an 8-digit YYYYMMDD date,
# so the test targets' plain "1" is left alone.
content, count_build = re.subn(
    r"CURRENT_PROJECT_VERSION = \d{8};",
    f"CURRENT_PROJECT_VERSION = {build_date};",
    content,
)

with open(path, "w") as f:
    f.write(content)

print(f"  MARKETING_VERSION: {count_marketing} occurrence(s) updated")
print(f"  CURRENT_PROJECT_VERSION: {count_build} occurrence(s) updated")
PYEOF

# Keep the README badge (e.g. "— v1.27") in sync too.
sed -i '' -E "s/— v[0-9]+\.[0-9]+/— v$NEW_VERSION/" "$README"

git add "$PBXPROJ" "$CHANGELOG" "$README"
git commit -m "Bump version to $NEW_VERSION (build $BUILD_DATE)"
git tag -a "$TAG" -m "Version $NEW_VERSION"

echo ""
echo "Done. Created commit and tag $TAG locally."
echo "Review with: git show $TAG"
echo "Push when ready with: git push origin main --tags"
