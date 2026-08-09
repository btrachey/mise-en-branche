#!/usr/bin/env bash
set -euo pipefail

# Requires git.sh for meb_slugify

# _meb_jira_curl — authenticated request against the Jira Cloud REST API
_meb_jira_curl() {
  curl -sf -u "${MEB_JIRA_EMAIL}:${MEB_JIRA_API_TOKEN}" \
    -H "Accept: application/json" \
    "$@"
}

# meb_issue_to_branch — resolve an issue ID to a branch name
# Usage: meb_issue_to_branch <id>
meb_issue_to_branch() {
  local id="$1"

  case "${MEB_TRACKER:-}" in
    github)
      local title number raw_branch
      # gh returns title and number as JSON
      read -r number title < <(
        gh issue view "$id" --repo "$MEB_REPO" --json title,number \
          --jq '[.number, .title] | @tsv'
      )
      raw_branch="gh-${number}/$(meb_slugify "$title")"
      echo "$raw_branch"
      ;;

    linear)
      local title slug
      # linear issue <ID> prints structured output; we parse the title line
      title=$(linear issue "$id" | grep -i '^title:' | sed 's/^[Tt]itle:[[:space:]]*//')
      slug=$(meb_slugify "$title")
      echo "${id}/${slug}"
      ;;

    jira)
      local key summary slug response
      response=$(_meb_jira_curl "${MEB_JIRA_BASE_URL}/rest/api/3/issue/${id}?fields=summary")
      key=$(echo "$response" | jq -r '.key')
      summary=$(echo "$response" | jq -r '.fields.summary')
      slug=$(meb_slugify "$summary")
      echo "${key}/${slug}"
      ;;

    none)
      echo "error: MEB_TRACKER=none — cannot resolve issue IDs" >&2
      exit 1
      ;;

    *)
      echo "error: unknown MEB_TRACKER value: ${MEB_TRACKER}" >&2
      exit 1
      ;;
  esac
}

# meb_issue_list — list open issues as ID<TAB>TITLE lines
meb_issue_list() {
  case "${MEB_TRACKER:-}" in
    github)
      gh issue list --repo "$MEB_REPO" --json number,title \
        --jq '.[] | "\(.number)\t\(.title)"'
      ;;

    linear)
      # linear issue list outputs a table; parse it into ID<TAB>TITLE
      linear issue list --team "$MEB_LINEAR_TEAM" \
        | tail -n +2 \
        | awk '{ print $1 "\t" $2 }'
      ;;

    jira)
      local jql body
      jql="project = \"${MEB_JIRA_PROJECT}\" AND statusCategory != Done ORDER BY created DESC"
      body=$(jq -n --arg jql "$jql" '{jql: $jql, fields: ["summary"], maxResults: 50}')
      _meb_jira_curl -X POST -H "Content-Type: application/json" -d "$body" \
        "${MEB_JIRA_BASE_URL}/rest/api/3/search/jql" \
        | jq -r '.issues[] | "\(.key)\t\(.fields.summary)"'
      ;;

    none)
      echo "error: MEB_TRACKER=none — no issue tracker configured" >&2
      exit 1
      ;;

    *)
      echo "error: unknown MEB_TRACKER value: ${MEB_TRACKER}" >&2
      exit 1
      ;;
  esac
}
