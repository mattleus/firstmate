#!/usr/bin/env bash
# fm-steer-validation-run.sh - send the one fixed "start your validation run"
# steer to a ship worker that committed its change but never started the
# no-mistakes run its delivery mode requires (committed head, no run on the
# ship branch, nothing in review).
#
# This script is the single owner of that steer's text, bin/fm-branch-prompt.sh
# names it as the trigger's handler, and tests/fm-branch-supervision.test.sh
# pins both halves. The steer used to be composed fresh by whichever supervisor
# noticed the gap, and two compositions of the identical gap differed in flag
# vocabulary: one carried an auto-resolve flag the fleet bans in every no-mistakes
# brief (owner: bin/fm-dod-lib.sh), because that ban lives in brief and skill
# surfaces the composer may or may not honor at composition time. The gap's
# shape is fixed and recurring, so the instruction is fixed and reviewed here
# instead of re-improvised, and it carries no pipeline flags beyond --intent by
# construction. Callers pass only the task id; this script checks the task's
# record, picks the review-forge variant, and sends through bin/fm-send.sh.
#
# Usage: fm-steer-validation-run.sh <task-id>
#
# Guards - each a loud refusal (exit 6) that sends nothing:
#   - no recorded task metadata for the id in this home;
#   - kind other than ship (scouts and second mates never drive a no-mistakes
#     validation of their own);
#   - a recorded mode other than no-mistakes, or none at all (a direct-PR or
#     local-only worker must never be steered onto the pipeline);
#   - no recorded ship branch or project;
#   - an unreadable or unknown registered forge for that project (the variant
#     must not be guessed: a Gerrit pipeline opens no pull request, so sending
#     the PR wording there would missteer).
# Anything else exits with bin/fm-send.sh's own status.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"

usage() {
  echo "usage: fm-steer-validation-run.sh <task-id>" >&2
  exit 2
}

refuse() { # <reason>
  echo "error: $*" >&2
  exit 6
}

[ $# -eq 1 ] && [ -n "${1:-}" ] || usage
TASK=$1

# fm-send's own resolution accepts a legacy fm-<id> label; the record lookup
# strips it the same way so both read the same task.
ID=${TASK#fm-}
META="$STATE/$ID.meta"
[ -f "$META" ] || refuse "$ID has no recorded task metadata in this home (tried $META)"

meta_field() { # <key> -> last key= value recorded in the task's meta
  grep "^$1=" "$META" 2>/dev/null | tail -1 | cut -d= -f2-
}

KIND=$(meta_field kind)
[ "$KIND" = "ship" ] ||
  refuse "$ID is kind=${KIND:-<unset>}: only a ship worker drives its task's validation run"

MODE=$(meta_field mode)
[ "$MODE" = "no-mistakes" ] ||
  refuse "$ID ships mode=${MODE:-<unset>}: the missing-validation steer applies only to mode=no-mistakes"

BRANCH=$(meta_field branch)
[ -n "$BRANCH" ] || refuse "$ID records no ship branch"

PROJECT=$(meta_field project)
[ -n "$PROJECT" ] || refuse "$ID records no project, so its review forge cannot be resolved"
PROJ_NAME=$(basename "$PROJECT")

FORGE=$("$SCRIPT_DIR/fm-project-mode.sh" --forge "$PROJ_NAME") ||
  refuse "$ID: the registered forge of project $PROJ_NAME could not be resolved (see fm-project-mode output above)"

rule_lines="Your brief's no-mistakes rules apply in full, including its ask-user finding rule: escalate every ask-user finding to firstmate the way that rule requires, and never answer one yourself."

case "$FORGE" in
  gerrit)
    TEXT=$(cat <<EOF
This task is not done: it ships mode=no-mistakes, and your branch \`$BRANCH\` has no no-mistakes validation run yet.
From your task copy, start the pipeline now: \`no-mistakes axi run --intent "<this brief's Captain's intent>"\`, then drive it to an outcome exactly as your brief's no-mistakes rules direct.
$rule_lines
Once the run reaches its outcome, follow your brief's publish sequence the way it requires and report the published change's full URL; do not report done before then.
EOF
)
    ;;
  none|forgejo)
    TEXT=$(cat <<EOF
This task is not done: it ships mode=no-mistakes, and your branch \`$BRANCH\` has no no-mistakes validation run and no pull request yet.
From your task copy, start the pipeline now: \`no-mistakes axi run --intent "<this brief's Captain's intent>"\`, then drive it to a gate or outcome exactly as your brief's no-mistakes rules direct.
$rule_lines
Report the PR's full URL when the pipeline opens it, and do not report done again before then.
EOF
)
    ;;
  *) refuse "$ID: project $PROJ_NAME resolved to an unknown forge \"$FORGE\"; the steer text has no variant for it" ;;
esac

FM_HOME="$FM_HOME" FM_ROOT_OVERRIDE="$FM_ROOT" FM_STATE_OVERRIDE="$STATE" \
  "$SCRIPT_DIR/fm-send.sh" "$TASK" "$TEXT"
echo "sent $ID: fixed start-validation steer for $BRANCH (forge $FORGE)"
