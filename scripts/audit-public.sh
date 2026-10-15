#!/usr/bin/env bash
#
# Pre-publish audit. Run before every push to a public remote.
#
#   ./scripts/audit-public.sh          check the working tree and full history
#   ./scripts/audit-public.sh --staged check only what is staged (used by the hook)
#
# Exits non-zero on any finding. No dependencies beyond git and grep;
# gitleaks is used additionally when it happens to be installed.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

STAGED=0
[ "${1:-}" = "--staged" ] && STAGED=1
FINDINGS=0

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }

# fail <headline> [detail-blob] [hint]
fail() {
  red "FAIL  $1"
  [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'
  [ -n "${3:-}" ] && printf '%s\n' "$3" | sed '1s/^/      -> /; 1!s/^/         /'
  FINDINGS=$((FINDINGS+1))
}
pass() { grn "ok    $1"; }

# AWS-owned account IDs that legitimately appear in policies and docs.
ALLOWED_ACCOUNTS='127311923021|033677994240|156460612806|797873946194|054676820928|582318560864'

# These files exist to describe the patterns, so they always match them.
SELF='^(scripts/audit-public\.sh|\.gitleaks\.toml|docs/publishing\.md)$'

if [ "$STAGED" -eq 1 ]; then
  FILES=$(git diff --cached --name-only --diff-filter=ACM)
  content() { git show ":$1" 2>/dev/null; }
else
  FILES=$(git ls-files)
  content() { cat "$1" 2>/dev/null; }
fi

############################################################
# 1. Files that must never be tracked
############################################################
BANNED='(^|/)(terraform\.tfvars|backend\.hcl|bootstrap\.xml)$|\.tfstate($|\.)|\.auto\.tfvars$|\.tfplan$|\.pem$|\.key$|(^|/)\.terraform/'
HITS=$(printf '%s\n' "$FILES" | grep -nE "$BANNED" || true)
if [ -n "$HITS" ]; then
  fail "tracked files that must stay local" "$HITS" \
       "$(printf 'these hold real values. .gitignore does not apply to files already in\nthe index, so untrack them (this keeps them on disk):\n\n  git rm --cached <path>\n  git commit --amend --no-edit    # if they are in the last commit\n\nKeep only the .example template tracked.')"
else
  pass "no banned filenames tracked"
fi

############################################################
# 2. AWS account IDs
############################################################
ACCT=""
for f in $FILES; do
  echo "$f" | grep -qE "$SELF" && continue
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ACCT="${ACCT}${f}: ${line}"$'\n'
  done < <(content "$f" | grep -noE '\b[0-9]{12}\b' | grep -vE ":($ALLOWED_ACCOUNTS)\$" || true)
done
if [ -n "$ACCT" ]; then
  fail "12-digit values that look like AWS account IDs" "$(printf '%s' "$ACCT" | head -20)" \
       "use the <ACCOUNT_ID> placeholder, or add the ID to ALLOWED_ACCOUNTS if AWS-owned"
else
  pass "no AWS account IDs"
fi

############################################################
# 3. Credentials
############################################################
CRED=""
for f in $FILES; do
  echo "$f" | grep -qE "$SELF" && continue
  out=$(content "$f" | grep -noE '\b(AKIA|ASIA|AROA|AIDA|AGPA|ANPA)[0-9A-Z]{16}\b|BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY|aws_secret_access_key|xox[baprs]-[0-9A-Za-z-]{10,}' || true)
  [ -n "$out" ] && CRED="${CRED}${f}: ${out}"$'\n'
done
if [ -n "$CRED" ]; then
  fail "credential-shaped strings" "$(printf '%s' "$CRED" | head -20)"
else
  pass "no credential patterns"
fi

############################################################
# 4. Secret-bearing Terraform variables with a literal value
############################################################
SECRETVAR=""
for f in $FILES; do
  echo "$f" | grep -qE "$SELF" && continue
  out=$(content "$f" | grep -noE '^[[:space:]]*(vm_auth_key|vm_series_auth_codes|certificate_arn|panorama_server|panorama_server_2)[[:space:]]*=[[:space:]]*"[^"]+"' || true)
  [ -n "$out" ] && SECRETVAR="${SECRETVAR}${f}: ${out}"$'\n'
done
if [ -n "$SECRETVAR" ]; then
  fail "sensitive variables assigned a literal value" "$(printf '%s' "$SECRETVAR" | head -20)" \
       "supply these from a secret store at apply time, not from a tracked file"
else
  pass "no sensitive variables with literal values"
fi

############################################################
# 5. History - .gitignore does nothing about what is already committed
############################################################
# One root commit is the common case right after the .example split: amending
# rewrites the only commit there is, so the orphan dance is unnecessary.
COMMIT_COUNT=$(git rev-list --all --count 2>/dev/null || echo 0)

if [ "$COMMIT_COUNT" -le 1 ]; then
  SQUASH_HINT="this repo has a single commit, so untracking and amending rewrites all of it:

  git rm --cached <the paths listed above>
  git commit --amend --no-edit
  git reflog expire --expire=now --all && git gc --prune=now
  ./scripts/audit-public.sh"
else
  SQUASH_HINT="If this repo has never been pushed, collapse it into one clean commit:

  git checkout --orphan public-main
  git rm --cached <any real-value files still tracked>
  git add -A
  git commit -m \"Initial public release\"
  git branch -D main 2>/dev/null || git branch -D master
  git branch -m main
  git reflog expire --expire=now --all && git gc --prune=now

If it HAS already been pushed, squashing is not enough - use git filter-repo
and rotate anything that was exposed."
fi

if [ "$STAGED" -eq 0 ]; then
  HIST=$(git log --all -p --no-color 2>/dev/null \
    | grep -E '^\+' \
    | grep -oE '\b(AKIA|ASIA)[0-9A-Z]{16}\b|\b[0-9]{12}\b' \
    | grep -vE "^($ALLOWED_ACCOUNTS)\$" | sort -u || true)
  if [ -n "$HIST" ]; then
    fail "sensitive values present in commit history" "$HIST" \
         "$(printf 'a value removed in a later commit is still served at the old SHA.\n%s' "$SQUASH_HINT")"
  else
    pass "commit history clean"
  fi

  BANNED_HIST=$(git log --all --pretty=format: --name-only 2>/dev/null | sort -u | grep -E "$BANNED" || true)
  if [ -n "$BANNED_HIST" ]; then
    fail "banned files appear somewhere in history" "$BANNED_HIST" \
         "$(printf 'committed before the .example split - the paths and contents are still in history.\n%s' "$SQUASH_HINT")"
  else
    pass "no banned files in history"
  fi
fi

############################################################
# 6. gitleaks, when available
############################################################
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks detect --no-banner --redact -c .gitleaks.toml >/dev/null 2>&1; then
    pass "gitleaks clean"
  else
    fail "gitleaks reported findings" "" "run: gitleaks detect --redact -c .gitleaks.toml"
  fi
else
  note "gitleaks not installed - skipping (brew install gitleaks)"
fi

echo
if [ "$FINDINGS" -gt 0 ]; then
  red "$FINDINGS check(s) failed - do not push"
  exit 1
fi
grn "all checks passed"
