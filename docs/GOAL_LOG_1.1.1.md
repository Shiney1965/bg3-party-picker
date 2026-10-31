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
| 1 | Plan reviewed adversarially (approve with changes; 8 should-fixes taken into the plan's "Plan review" section; Unit L rewritten to the author's decision). Units A-L implemented (commit 63d4806); new tests: server section 34 + the Halsin dead-member lines in section 32, client section 9, mock column counts; the new checks were run against the 1.1.0 code and fail there (C, D, E, F, G, H, L server; I, J, A client; client D not reached on 1.1.0 because the run stopped at A). Version 1.1.1 (Common.lua; meta.lsx L35/L38 = 36169536654802944, L15 untouched). Diff reviewed adversarially (fix first: one should-fix, dead camp member waits forever in a restore; fixed with a test that fails on 63d4806; four minors fixed, two noted; see the plan's "Diff review" section; commit 5463b04). Pak built from an LF export (`git -c core.autocrlf=false checkout-index` into an empty folder): 57,682 bytes, SHA-256 4193a858…33ac2f3; extracted: no CR bytes, no name, versions 1.1.1. RUN_CARD 1.1.1 entry; docs/TEST_CARD_1.1.1.md; CLAUDE.md version line; RESEARCH.md story tables. Tests 280 server + 38 client + blueprint pass. | docs/PLAN_1.1.1_review_fixes.md, src/, tests/, PartyPicker.pak, RUN_CARD.md, docs/TEST_CARD_1.1.1.md, docs/RESEARCH.md, CLAUDE.md, this log | **NOT MET**. Blocking gap: Units F/G did not follow Plan review item 4 (Restore did not return the skipped list; autoRestore chose the notice kind by matching the message text). Also: camp night read per joiner instead of once per request and only for joins; tests missing for `!pp_set` with a dead party member and a night-time non-join change; RESEARCH.md named a third-party AI product (older text). Verified met: suite, version, pak rebuilt identical from an LF export, test card, pushed, not installed, not released. |
| 2 | Restore returns `skipped` (4th value) and autoRestore picks warning/info from it; the camp-night row is read once per request in Party.Apply and refuses any change (removed from JoinBlockedReason); tests added: `!pp_set` with a dead party member (accepted, body stays), sending to camp refused at night, one night read per request, Restore's skipped list; RESEARCH.md line reworded ("AI coding-assistant skills"). Tests 284 server + 38 client + blueprint pass. Pak rebuilt from a fresh LF export: 57,747 bytes, SHA-256 e5c0e1ca…12f27c339 (Python check: 0 CR bytes in export and extracted pak; no name; PP.VERSION 1.1.1). RUN_CARD updated. | src/Server/Restrictions.lua, src/Server/Party.lua, tests/test_server.lua, docs/RESEARCH.md, PartyPicker.pak, RUN_CARD.md, this log | **NOT MET**. Blocking gap: model-name text in changed files (this log's cycle-1 line quoted a product name; CLAUDE.md L1, its title line, and L7, a session link, both older than this work). Minor: no offline check of the Unit K text. Verified met: units A-L in code, suite, version, pak rebuilt identical (0 CR), test card, pushed, not released. Addendum: the install of 1.1.1 at the author's word was seen on disk (E5C0E1CA…). |
| 3 | This log's line reworded; Unit K check added to tests/run_tests.py (fails on the 1.1.0 text, passes now); install recorded in RUN_CARD.md and CLAUDE.md's version history. CLAUDE.md L1 and L7 not changed: that file holds the author's instructions, and a change asked for only by a verifier waits for the author (asked 2026-10-31). | tests/run_tests.py, RUN_CARD.md, CLAUDE.md (version history only), this log | stopped: waiting for the author's decision on CLAUDE.md L1/L7 |
