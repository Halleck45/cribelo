#!/usr/bin/env bash
# Posts the plan as one comment on a pull request, or updates the comment
# this token posted before. Usage: post-comment.sh OWNER/REPO PR PLAN_FILE
# Needs GH_TOKEN with pull-requests write. Exits non-zero when it cannot post.
set -euo pipefail

repo=$1 pr=$2 plan=$3
marker='<!-- cribelo-plan -->'
body="${RUNNER_TEMP:-/tmp}/cribelo-comment.md"

# A comment holds at most 65536 characters.
{ echo "$marker"; head -c 60000 "$plan"; } > "$body"

# Only update a comment written by this token: anyone can start a comment
# with the marker. GITHUB_TOKEN cannot read /user, its login is fixed.
login=$(gh api user --jq .login 2>/dev/null || echo 'github-actions[bot]')

existing=$(gh api "repos/$repo/issues/$pr/comments" --paginate \
  --jq ".[] | select(.user.login == \"$login\" and (.body | startswith(\"$marker\"))) | .id" | head -n1)

if [ -n "$existing" ]; then
  gh api -X PATCH "repos/$repo/issues/comments/$existing" -F body=@"$body" > /dev/null
else
  gh api "repos/$repo/issues/$pr/comments" -F body=@"$body" > /dev/null
fi
