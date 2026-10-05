# Matt Pocock engineering skills

FirstMate can use the [mattpocock/skills](https://github.com/mattpocock/skills) pack as an engineering-method library while retaining its own orchestration and delivery lifecycle.
FirstMate remains responsible for user decisions, worker allocation, isolation, supervision, pull requests, CI, and merge authority.
The external skills contribute methods such as diagnosis, test-driven development, module design, and domain modeling.

## Install

Install the complete pack globally for every agent harness that may run either the firstmate or its workers.
The complete pack matters because user-facing workflow skills delegate to smaller method skills by ID.

```sh
npx --yes skills@latest add mattpocock/skills \
  --skill '*' \
  --global \
  --agent claude-code \
  --agent codex \
  --agent opencode \
  --agent pi \
  --yes
```

Adjust the repeated `--agent` flags to the worker harnesses you actually use.
Do not install a second copy through another plugin system when that would expose duplicate skill definitions to the same harness.

## How routing works

Captain-facing workflows such as `grill-me` and `wayfinder` remain coordinated by FirstMate.
Project investigation, prototypes, implementation, and standalone reviews are dispatched through normal scout or ship work rather than through a nested agent fleet.
Publishing a plan, specification, ticket map, or investigation report never grants implementation authority.

Every newly scaffolded ship or scout instruction file records two task-specific inputs:

- Required skill IDs, or a reason no external method applies.
- Agreed public testing seams, or a reason no executable test applies.

The launch is refused while either input is still a scaffold placeholder or has an empty body.
If a named skill is unavailable to the worker, the worker reports the missing skill instead of silently falling back.
Saved instructions created before this contract remain launchable for recovery compatibility.

## Review ownership

The task's selected FirstMate delivery path remains the only final review owner.
In particular, a worker does not invoke `implement` or `code-review` as an extra completion flow when no-mistakes already owns review, fixes, tests, documentation, the pull request, and CI.
A standalone code review remains available when explicitly requested as its own deliverable.

## Project setup

This integration does not modify individual projects.
Run `setup-matt-pocock-skills` separately for a project only when you want its issue-tracker and domain-document conventions configured, and ship those changes through the project's existing FirstMate delivery policy.
