---
name: matt-pocock-integration
description: >-
  Agent-only routing for combining FirstMate with Matt Pocock's engineering skills.
  Use when the captain invokes one of those workflows, before translating it into FirstMate work, and before choosing a worker's required skills or agreed testing seams.
user-invocable: false
metadata:
  internal: true
---

# Matt Pocock skills integration

FirstMate owns the operating system of the work: captain interaction, authority, task classification, worker allocation, isolation, tracker mutation, supervision, delivery, and merge decisions.
Matt Pocock skills supply engineering methods inside that system.
When the two prescribe the same concern, keep FirstMate's lifecycle and use the upstream skill only for method.
For a captain-facing upstream workflow, load its installed skill and apply its interviewing, modeling, or writing method subject to the translations below.

## Translate workflows

| Upstream workflow | FirstMate route |
|---|---|
| `grill-me`, `grill-with-docs` | Keep the interview and decisions in the firstmate chat while delegating project investigation to scouts and approved repository changes to ships. |
| `wayfinder` | Keep the captain-facing decision map with firstmate while using scouts for research or prototypes, publishing planning artifacts through the project's approved path, and requiring separate implementation authorization. |
| `to-spec`, `to-tickets` | Preserve their planning output and dependency semantics because publishing a spec or tickets does not authorize implementation, while authorized tickets become ordinary FirstMate tasks. |
| `research`, `prototype`, `diagnosing-bugs` | Dispatch a scout when a separate evidence artifact is needed, retain the scout's report as durable evidence, and promote it only after implementation is authorized. |
| `implement` | Convert the accepted spec or tickets into ship tasks instead of invoking the upstream workflow inside a worker, where its delegation and final review steps would create a second lifecycle. |
| `code-review` | Use only when the captain explicitly requests a standalone review deliverable, dispatching it as dedicated review work rather than stacking it on a no-mistakes delivery. |
| `setup-matt-pocock-skills` | Treat setup as an explicit per-project change that inspects first, obtains the required project decisions, and ships the approved configuration through that project's delivery path. |

If another upstream skill creates subagents, mutates the issue tracker, opens a PR, or owns final review, route those actions through the corresponding FirstMate scout, ship, tracker, or delivery contract instead of running a nested workflow.

## Choose worker methods

Name upstream skills by exact ID in the worker's `## Required skills` subsection.
Reference the installed skill rather than copying its procedure into the instructions.

Use this starting map, then narrow it to what the task actually needs:

| Work shape | Method skills |
|---|---|
| Bug or regression | `diagnosing-bugs`, then `tdd` when an executable regression seam exists |
| Feature behavior | `tdd` |
| New or changed interface | `codebase-design`, plus `tdd` when executable behavior changes |
| Domain terminology or decisions | `domain-modeling` |
| Agent-consumed instructions | `writing-for-agents` |

Orchestration skills such as `wayfinder`, `research`, and `implement`, and final-review skills such as `code-review`, do not belong in a worker's required-method list.
The selected delivery contract remains the only final review owner, including no-mistakes when that mode is selected.

## Record the engineering contract

Before dispatch, fill every current ship or scout instruction scaffold as follows:

1. `## Required skills` lists each exact method skill ID as a bullet, or contains only `None - <reason>.` when no upstream method applies.
2. `## Agreed testing seams` lists the public interfaces already made explicit or agreed with the captain, or `None - <reason>.` when no executable test is appropriate.
3. The Firstmate specification names relevant `CONTEXT.md` files and ADRs when they exist, without copying their contents.

Do not silently replace a missing required skill with generic advice.
If no eligible worker can load it, report that blocker and ask whether to install the skill pack or revise the method.
Load `harness-adapters` before sending any harness-specific skill invocation to a live worker.

## Completion

The worker uses required skills during investigation and implementation, then follows only the existing Definition of done.
Planning and investigation findings are evidence, not implementation authority.
No upstream skill changes FirstMate's communication, approval, merge, or cleanup rules.
