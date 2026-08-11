#!/usr/bin/env bash

# Ensure the git user.name/user.email are set, configuring them from the
# authenticated gh account if not.
# - If both are already set, exit 0 immediately.
# - Otherwise fetch name/email from `gh api user`, falling back to login for a
#   missing name and to the GitHub noreply address for a missing email, then
#   apply whichever of user.name/user.email was still unset with
#   `git config --global`.
# - If `gh api user` fails, or a usable name/email still can't be resolved,
#   log the reason and exit 2.

set -euo pipefail

log() { echo "[setup-git-identity-from-gh] $*" >&2; }

exitWithBlockingError() {
  log "\`git\` identity (name + email) is not set and can not be setup from \`gh api user\` info (reason: $*) - either set \`git\` identity or \`gh auth login\` before retrying"
  exit 2
}

existing_git_name=$(git config user.name || true)
existing_git_email=$(git config user.email || true)

if [[ -n "$existing_git_name" && -n "$existing_git_email" ]]; then
  log "\`git\` identity already setup"
  exit 0
fi

git_name=$existing_git_name
git_email=$existing_git_email

if ! gh_user=$(gh api user 2>/dev/null); then
  exitWithBlockingError "\`gh api user\` failed: $gh_user"
fi

gh_login=$(jq -r '.login' <<<"$gh_user")
gh_id=$(jq -r '.id' <<<"$gh_user")
gh_name=$(jq -r '.name' <<<"$gh_user")
gh_email=$(jq -r '.email' <<<"$gh_user")

if [[ -z "$git_name" ]]; then
  git_name=$gh_name
  if [[ -z "$git_name" || "$git_name" == "null" ]]; then
    git_name="$gh_login"
    if [[ -z "$git_name" || "$git_name" == "null" ]]; then
      exitWithBlockingError "could not resolve a usable git name from \`gh api user\`"
    fi
  fi
fi

if [[ -z "$git_email" ]]; then
  git_email=$gh_email
  if [[ -z "$git_email" || "$git_email" == "null" ]]; then
    if [[ -z "$gh_login" || "$gh_login" == "null" || -z "$gh_id" || "$gh_id" == "null" ]]; then
      exitWithBlockingError "could not resolve a usable git email from \`gh api user\`"
    fi
    git_email="${gh_id}+${gh_login}@users.noreply.github.com"
  fi
fi

if [[ -z "$existing_git_name" ]]; then
  git config --global user.name "$git_name"
fi
if [[ -z "$existing_git_email" ]]; then
  git config --global user.email "$git_email"
fi
log "configured git identity: $git_name <$git_email>"
