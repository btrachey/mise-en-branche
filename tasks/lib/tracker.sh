#!/usr/bin/env bash
set -euo pipefail

# Requires git.sh for meb_slugify

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
