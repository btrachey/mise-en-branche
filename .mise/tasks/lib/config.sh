#!/usr/bin/env bash
set -euo pipefail

# _meb_prompt_and_set — prompt for a variable value and persist it via mise
# Exits 1 if the user provides an empty value.
# Usage: _meb_prompt_and_set VAR_NAME <gum args...>
_meb_prompt_and_set() {
  local var_name="$1"
  shift
  local value
  value=$("$@")
  if [[ -z "$value" ]]; then
    echo "error: $var_name is required" >&2
    exit 1
  fi
  mise set "${var_name}=${value}" --env local
  export "${var_name}=${value}"
}

# _meb_prompt_and_set_optional — prompt for an optional variable; skip if empty
# Usage: _meb_prompt_and_set_optional VAR_NAME <gum args...>
_meb_prompt_and_set_optional() {
  local var_name="$1"
  shift
  local value
  value=$("$@") || true
  if [[ -n "$value" ]]; then
    mise set "${var_name}=${value}" --env local
    export "${var_name}=${value}"
  fi
}

# meb_config_validate — assert required MEB_* variables are set, exit 1 if not
meb_config_validate() {
  if [[ -z "${MEB_REPO:-}" ]]; then
    echo "error: MEB_REPO is not set. Run 'mise run init' to configure." >&2
    exit 1
  fi

  if [[ -z "${MEB_TRACKER:-}" ]]; then
    echo "error: MEB_TRACKER is not set. Run 'mise run init' to configure." >&2
    exit 1
  fi

  case "$MEB_TRACKER" in
    github|linear|jira|none) ;;
    *)
      echo "error: MEB_TRACKER must be \"github\", \"linear\", \"jira\", or \"none\" (got: \"$MEB_TRACKER\")" >&2
      exit 1
      ;;
  esac

  if [[ "$MEB_TRACKER" == "linear" && -z "${MEB_LINEAR_TEAM:-}" ]]; then
    echo "error: MEB_LINEAR_TEAM is required when MEB_TRACKER=linear. Run 'mise run init' to configure." >&2
    exit 1
  fi

  if [[ "$MEB_TRACKER" == "jira" ]]; then
    local var
    for var in MEB_JIRA_BASE_URL MEB_JIRA_PROJECT MEB_JIRA_EMAIL MEB_JIRA_API_TOKEN; do
      if [[ -z "${!var:-}" ]]; then
        echo "error: $var is required when MEB_TRACKER=jira. Run 'mise run init' to configure." >&2
        exit 1
      fi
    done
  fi
}

# meb_default_branch — return the default branch name
meb_default_branch() {
  if [[ -n "${MEB_DEFAULT_BRANCH:-}" ]]; then
    echo "$MEB_DEFAULT_BRANCH"
    return
  fi
  gh repo view "$MEB_REPO" --json defaultBranchRef --jq '.defaultBranchRef.name'
}
