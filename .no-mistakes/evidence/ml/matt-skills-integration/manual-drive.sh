#!/usr/bin/env bash
# Manual live drives for the Matt Pocock skills integration, against the real
# bin/fm-brief.sh, bin/fm-spawn.sh, and bin/fm-promote.sh in the worktree.
set -u
ROOT=/Users/matt/.no-mistakes/worktrees/e1a436203903/01M45BVVZ7BDQHBZZ36AFF6QTX
EVIDENCE=/Users/matt/.no-mistakes/evidence/01M45BVVZ7BDQHBZZ36AFF6QTX
WORK=$(mktemp -d "${TMPDIR:-/tmp}/fm-mp-drive.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
FAILED=0
note() { printf '%s\n' "$*"; }
check() { # <label> <condition-status> <detail>
  if [ "$2" -eq 0 ]; then note "PASS: $1"; else note "FAIL: $1 - $3"; FAILED=1; fi
}

SPAWN="$ROOT/bin/fm-spawn.sh"
BRIEF="$ROOT/bin/fm-brief.sh"
PROMOTE="$ROOT/bin/fm-promote.sh"

make_home() { # <name>
  local name=$1 home=$WORK/$1
  mkdir -p "$home/home/data" "$home/home/state" "$home/home/config" "$home/projects/proj" "$home/bin"
  git -C "$home/projects/proj" init -q
  printf '#!/bin/sh\nexit 1\n' > "$home/bin/tmux"
  chmod +x "$home/bin/tmux"
  printf '%s\n' "$home/home"
}

run_spawn() { # <home> <bin> <args...>
  local home=$1 bin=$2; shift 2
  env -u NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS=1 \
    FM_ROOT_OVERRIDE='' FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$WORK/projects-unused" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_BACKEND=tmux PATH="$bin:$PATH" \
    "$SPAWN" "$@" 2>&1
}

fill() { # <file> <intent> <spec> [<skills> <seams>]
  local file=$1 content
  content=$(cat "$file")
  content=${content//'{TASK}'/$2}
  content=${content//'{FIRSTMATE_SPEC}'/$3}
  if [ $# -ge 5 ]; then
    content=${content//'{REQUIRED_SKILLS}'/$4}
    content=${content//'{TESTING_SEAMS}'/$5}
  fi
  printf '%s\n' "$content" > "$file"
}

note '=== S1: fm-brief scaffolds ship and scout briefs carrying the Engineering method contract ==='
HOME1=$(make_home s1)
cd "$WORK/s1"
FM_HOME="$HOME1" "$BRIEF" mp-ship proj --mode direct-PR >"$WORK/s1/ship.out" 2>&1
check "ship scaffold exits zero" $? "$(cat "$WORK/s1/ship.out")"
cp "$HOME1/data/mp-ship/brief.md" "$EVIDENCE/s1-ship-brief.md"
FM_HOME="$HOME1" "$BRIEF" mp-scout proj --scout >"$WORK/s1/scout.out" 2>&1
check "scout scaffold exits zero" $? "$(cat "$WORK/s1/scout.out")"
cp "$HOME1/data/mp-scout/brief.md" "$EVIDENCE/s1-scout-brief.md"
grep -q '# Engineering method' "$HOME1/data/mp-ship/brief.md"; check "ship brief has # Engineering method" $? ''
grep -q '{REQUIRED_SKILLS}' "$HOME1/data/mp-ship/brief.md"; check "ship brief has {REQUIRED_SKILLS}" $? ''
grep -q '{TESTING_SEAMS}' "$HOME1/data/mp-ship/brief.md"; check "ship brief has {TESTING_SEAMS}" $? ''
grep -q "Do not invoke \`code-review\`, \`implement\`, \`research\`, \`wayfinder\`" "$HOME1/data/mp-ship/brief.md"
check "ship brief forbids nested orchestration/duplicate delivery flows" $? ''
grep -q "FirstMate's selected delivery path is the only final review owner." "$HOME1/data/mp-ship/brief.md"
check "ship brief keeps final review with FirstMate's delivery path" $? ''
grep -q '# Engineering method' "$HOME1/data/mp-scout/brief.md"; check "scout brief has # Engineering method" $? ''
grep -q '{REQUIRED_SKILLS}' "$HOME1/data/mp-scout/brief.md"; check "scout brief has {REQUIRED_SKILLS}" $? ''
FM_SECONDMATE_CHARTER='Supervise the alpha domain.' FM_HOME="$HOME1" "$BRIEF" mp-sm --secondmate alpha >"$WORK/s1/sm.out" 2>&1
check "secondmate charter scaffolds" $? "$(cat "$WORK/s1/sm.out")"
grep -q '# Engineering method' "$HOME1/data/mp-sm/brief.md"
check "secondmate charter carries NO engineering method section" $((1-$?)) ''

note '=== S2: legacy brief with no Engineering method section still passes spawn validation (recovery compatibility) ==='
D2=$WORK/s2; HOME2=$(make_home s2); PROJ2="$WORK/s2/projects/proj"; BIN2="$WORK/s2/bin"
mkdir -p "$HOME2/data/legacy-ship"
cat > "$HOME2/data/legacy-ship/brief.md" <<'EOF'
You are a crewmate.

# Task
## Captain's intent
Recover the saved instructions.

## Firstmate spec
Launch with the recorded contract.

# Definition of done
Delivery contract: mode=direct-PR
EOF
out=$(run_spawn "$HOME2" "$BIN2" legacy-ship "$PROJ2" claude --mode direct-PR --yolo off)
printf '%s\n' "$out" > "$EVIDENCE/s2-legacy-spawn-output.txt"
printf '%s\n' "$out" | grep -qi 'engineering method'
check "legacy brief is NOT refused for a missing engineering method" $((1-$?)) "$out"
printf '%s\n' "$out" | grep -q '^error:'
check "legacy brief produced NO validation error" $((1-$?)) "$out"
# Engineering validation (bin/fm-spawn.sh:2554) runs strictly before the rigor
# notice (bin/fm-spawn.sh:2634), so reaching the notice proves validation passed;
# the fake tmux then stops the run before any window, worktree, or meta exists.
printf '%s\n' "$out" | grep -q 'less rigor than the captain'
check "legacy brief passed validation and reached the post-validation flow" $? "$out"
[ ! -e "$HOME2/state/legacy-ship.meta" ]
check "fake-tmux stop left no task metadata behind" $? ''

note '=== S3: fm-promote refuses a scout brief with unfilled engineering placeholders (adversarial) ==='
HOME3=$(make_home s3)
printf 'window=fm-promote-unfilled\nkind=scout\nworktree=/tmp/wt\n' > "$HOME3/state/promote-unfilled.meta"
FM_HOME="$HOME3" "$BRIEF" promote-unfilled proj --scout >/dev/null 2>&1
fill "$HOME3/data/promote-unfilled/brief.md" "Ship the promoted work." "Keep the selected delivery mode."
out=$(env -u NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME3" FM_STATE_OVERRIDE="$HOME3/state" "$PROMOTE" promote-unfilled --mode direct-PR --yolo off 2>&1)
status=$?
printf 'exit=%s\n%s\n' "$status" "$out" > "$EVIDENCE/s3-promote-refusal.txt"
[ "$status" -ne 0 ]; check "promotion with unfilled engineering placeholders exits non-zero" $? 'promoted anyway'
printf '%s\n' "$out" | grep -q 'still contains {REQUIRED_SKILLS} or {TESTING_SEAMS}'
check "promotion refusal names the unfilled engineering placeholders" $? "$out"
printf '%s\n' "$out" | grep -q 'fill ## Required skills and ## Agreed testing seams before promotion'
check "promotion refusal names the subsections to fill" $? "$out"
[ ! -f "$HOME3/data/promote-unfilled/ship-instructions.md" ]
check "refused promotion publishes no ship instructions" $? ''

note '=== S4: spawn refuses a brief whose engineering subsection bodies were emptied (adversarial) ==='
D4=$WORK/s4; HOME4=$(make_home s4); PROJ4="$WORK/s4/projects/proj"; BIN4="$WORK/s4/bin"
FM_HOME="$HOME4" "$BRIEF" empty-skills proj --mode direct-PR >/dev/null 2>&1
fill "$HOME4/data/empty-skills/brief.md" "Ship something." "Keep the delivery contract." '' ''
out=$(run_spawn "$HOME4" "$BIN4" empty-skills "$PROJ4" claude --mode direct-PR --yolo off)
status=$?
printf 'exit=%s\n%s\n' "$status" "$out" > "$EVIDENCE/s4-spawn-empty-refusal.txt"
[ "$status" -ne 0 ]; check "spawn with empty engineering bodies exits non-zero" $? 'spawned anyway'
printf '%s\n' "$out" | grep -q 'must contain nonempty ## Required skills and ## Agreed testing seams'
check "spawn refuses with the nonempty-subsection error" $? "$out"
[ ! -f "$HOME4/state/empty-skills.meta" ]
check "refused spawn wrote no task metadata" $? ''

note '=== S5: legacy scout brief with no Engineering method section still promotes (recovery compatibility) ==='
HOME5=$(make_home s5)
printf 'window=fm-promote-legacy\nkind=scout\nworktree=/tmp/wt\n' > "$HOME5/state/promote-legacy.meta"
mkdir -p "$HOME5/data/promote-legacy"
cat > "$HOME5/data/promote-legacy/brief.md" <<'EOF'
You are a crewmate.

# Task
## Captain's intent
Ship the recovered scout work.

## Firstmate spec
Deliver through the recorded mode.
EOF
out=$(env -u NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS=1 FM_HOME="$HOME5" FM_STATE_OVERRIDE="$HOME5/state" "$PROMOTE" promote-legacy --mode direct-PR --yolo off 2>&1)
status=$?
printf 'exit=%s\n%s\n' "$status" "$out" > "$EVIDENCE/s5-legacy-promote.txt"
printf '%s\n' "$out" | grep -qi 'engineering method'
check "legacy scout promotion is NOT refused for a missing engineering method" $((1-$?)) "$out"
[ -f "$HOME5/data/promote-legacy/ship-instructions.md" ]
check "legacy scout promotion publishes ship instructions" $? "$out"
grep -q '^Delivery contract: mode=direct-PR' "$HOME5/data/promote-legacy/ship-instructions.md" \
  || grep -q 'Delivery contract: mode=direct-PR' "$HOME5/data/promote-legacy/ship-instructions.md"
check "legacy promoted instructions carry the delivery contract" $? ''
if [ -f "$HOME5/data/promote-legacy/ship-instructions.md" ]; then
  cp "$HOME5/data/promote-legacy/ship-instructions.md" "$EVIDENCE/s5-legacy-ship-instructions.md"
fi

note "=== overall: $([ "$FAILED" -eq 0 ] && echo ALL-PASS || echo HAS-FAILURES) ==="
exit "$FAILED"
