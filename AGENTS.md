# TastePassport Agent Instructions

## Project scope
TastePassport is an AI-assisted cultural taste translation product. Treat this repository as its own subproject with its own architecture, experiments, protocols, and decisions.

## Source of truth
- GitHub committed code and committed protocol documents are the source of truth.
- Do not silently reinterpret or replace frozen protocol decisions.
- Preserve historical invalid/failed experiment records; never rewrite them as successful evidence.

## Architectural discipline
- Do not implement features when an architectural assumption is unresolved.
- Before costly-to-reverse changes, stop at an explicit validation gate.
- Distinguish confirmed facts, assumptions, hypotheses, and unresolved issues in PR descriptions.
- Prefer reproducible tests, API documentation, and deterministic checks over assumptions.

## Qloo rules
- Qloo remains the recommendation decision source for venue selection.
- Do not let an LLM invent, reorder, or substitute final venues.
- Do not assign synthetic affinity scores or zeros to entities omitted by Qloo.
- Do not use intersection-only candidate pools as a hidden workaround for signal-conditioned omissions.
- Do not run profile-conditioned confirmatory Qloo retrieval unless a corresponding protocol has been pre-registered, committed, and passed repository validation.
- Treat the existing QMBT-1 invalid execution and fixed-pool diagnostic failure as diagnostic evidence only, not product-hypothesis evidence.

## Current experimental direction
- Fixed-pool rescoring is retired unless a future documented Qloo capability is separately validated before use.
- The next intended research direction is retrieval-native, quota-matched independent retrieval with a new holdout set (QMBT-2R or successor name).
- Do not create or run that confirmatory experiment until its protocol is committed first.
- Do not lower frozen success thresholds, drop difficult cases post hoc, or tune on confirmatory holdout outputs.

## Compliance and safety
- Never expose API keys, passwords, tokens, recovery codes, or other secrets in code, logs, commits, issues, or PRs.
- Keep deterministic safety/compliance rules outside LLM control where appropriate.
- Product features must avoid workflows that conflict with Islamic principles. If a genuine religious-compliance question is uncertain, flag it for qualified scholarly review instead of guessing.
- Do not introduce nightlife/alcohol-oriented recommendation categories.
- Restaurant retrieval in experiments is validation infrastructure only and is not a halal endorsement; production compliance filtering remains mandatory.

## Git and pull-request workflow
- Work on a dedicated branch for each task unless explicitly instructed otherwise.
- Keep commits focused and reversible.
- Run repository validation before proposing merge.
- Never merge to main automatically.
- Open or update a PR and stop for human review when a validation gate or architectural decision is reached.
- In the PR description, report: what changed, why, tests run, known risks, and any unresolved decision.

## Testing expectations
- PowerShell scripts must parse successfully.
- Preserve existing CI safety invariants unless the protocol itself is deliberately and explicitly superseded in a reviewed commit.
- Prefer static or mocked tests when live Qloo calls are not required.
- Do not add live secret-dependent calls to CI without explicit approval.

## Agent autonomy boundaries
The agent may autonomously:
- inspect the repository;
- improve documentation;
- refactor code without changing frozen behavior;
- add deterministic tests and static validation;
- implement a clearly specified task that does not cross an unresolved architecture gate;
- prepare a branch and PR for review.

The agent must stop and request human review before:
- changing product requirements;
- changing experiment success thresholds;
- selecting new confirmatory cases or holdouts after inspecting their outputs;
- making live profile-conditioned Qloo calls;
- changing security/compliance policy;
- merging to main;
- deleting historical evidence or invalid-run records.
