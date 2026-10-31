# Goal log - Party Picker 1.1.1 TEST build

The author, 2026-10-31: "Please pursue this fix as a /goal". Also: "other than my comment about Point 3 I accept your
recommendations."

## Completion condition (verbatim)
GOAL: Party Picker 1.1.1 TEST build is complete on main: every unit A-L of docs/PLAN_1.1.1_review_fixes.md is
implemented as the plan states (the plan reviewed adversarially and its blockers addressed in the plan), each unit
has offline test scenarios and the whole suite passes (python tests/run_tests.py, 0 failed), the diff was reviewed
adversarially with every blocker fixed, PP.VERSION is "1.1.1" and both meta.lsx Version64 values are
36169536654802944, PartyPicker.pak 1.1.1 is built from an LF export with its size + SHA-256 recorded in RUN_CARD.md,
docs/TEST_CARD_1.1.1.md exists, no real name or model name in any changed file or commit, and everything is
committed and pushed to origin/main. Not installed, not released (those wait for the author).

## Proof artifacts
origin/main: docs/PLAN_1.1.1_review_fixes.md (with a review section), src/ (the changes), tests/ (new scenarios),
RUN_CARD.md, docs/TEST_CARD_1.1.1.md, PartyPicker.pak, this log.

## Cap
8 cycles (default; none given).

## Cycles
| Cycle | Work done | Artifacts changed | Verifier verdict |
|---|---|---|---|
| 1 | Plan reviewed adversarially (approve with changes; 8 should-fixes taken into the plan's "Plan review" section; Unit L rewritten to the author's decision). Units A-L implemented (commit 63d4806); new tests: server section 34 + the Halsin dead-member lines in section 32, client section 9, mock column counts; the new checks were run against the 1.1.0 code and fail there (C, D, E, F, G, H, L server; I, J, A client; client D not reached on 1.1.0 because the run stopped at A). Version 1.1.1 (Common.lua; meta.lsx L35/L38 = 36169536654802944, L15 untouched). Diff reviewed adversarially (fix first: one should-fix, dead camp member waits forever in a restore; fixed with a test that fails on 63d4806; four minors fixed, two noted; see the plan's "Diff review" section; commit 5463b04). Pak built from an LF export (`git -c core.autocrlf=false checkout-index` into an empty folder): 57,682 bytes, SHA-256 4193a858…33ac2f3; extracted: no CR bytes, no name, versions 1.1.1. RUN_CARD 1.1.1 entry; docs/TEST_CARD_1.1.1.md; CLAUDE.md version line; RESEARCH.md story tables. Tests 280 server + 38 client + blueprint pass. | docs/PLAN_1.1.1_review_fixes.md, src/, tests/, PartyPicker.pak, RUN_CARD.md, docs/TEST_CARD_1.1.1.md, docs/RESEARCH.md, CLAUDE.md, this log | (pending) |
