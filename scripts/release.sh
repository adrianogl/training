#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

LAST_TAG=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
if [[ -z "$LAST_TAG" ]]; then
  echo "Nenhuma tag v* encontrada. Crie a primeira com: git tag v1.0.0" >&2
  exit 1
fi

IFS=. read -r MAJOR MINOR PATCH <<< "${LAST_TAG#v}"
LOG=$(git log "$LAST_TAG"..HEAD --no-merges --format='%s%n%b%n--')

if grep -qE '^[a-z]+(\([^)]*\))?!:|^BREAKING CHANGE' <<< "$LOG"; then
  BUMP=major
elif grep -qE '^feat(\([^)]*\))?:' <<< "$LOG"; then
  BUMP=minor
elif grep -qE '^(fix|perf)(\([^)]*\))?:' <<< "$LOG"; then
  BUMP=patch
else
  echo "Nada para lançar desde $LAST_TAG (só chore, docs, refactor ou test)."
  exit 0
fi

case $BUMP in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac
VERSION="$MAJOR.$MINOR.$PATCH"
BUILD=$(( $(sed -nE 's/^ *CURRENT_PROJECT_VERSION: "([0-9]+)"/\1/p' project.yml | head -1) + 1 ))

echo "$LAST_TAG -> v$VERSION ($BUMP), build $BUILD"
git log "$LAST_TAG"..HEAD --no-merges --format='  %s'
$DRY_RUN && exit 0

sed -i '' -E "s/^( *MARKETING_VERSION: )\"[^\"]*\"/\1\"$VERSION\"/; s/^( *CURRENT_PROJECT_VERSION: )\"[^\"]*\"/\1\"$BUILD\"/" project.yml
echo "project.yml atualizado. Commit: chore(release): v$VERSION · tag: v$VERSION"
