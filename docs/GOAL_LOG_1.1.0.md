# Goal log: Party Picker 1.1.0 release package (2026-10-31)

**Condition (verbatim):** Party Picker 1.1.0 release package is complete: all Inspiration features removed from
main per docs/PLAN_ship_without_inspiration.md (plan reviewed adversarially, blockers addressed), tests pass, the
diff reviewed adversarially with blockers fixed, PartyPicker.pak 1.1.0 built from an LF export with size + SHA-256
in RUN_CARD.md, release documentation in dist_docs updated for 1.1.0 (README, INSTALL, CHANGELOG, RELEASE_NOTES,
Nexus BBCode/description; no Inspiration feature mentioned; no unverified limitations; no real name; no model
names), rendered docs regenerated, the bundle + zip assembled in release\PartyPicker-1.1.0, everything committed
and pushed to main.

**Proof artifacts:** the repo at main (src, tests, RUN_CARD.md, dist_docs), PartyPicker.pak, the plan and its
review record, release\PartyPicker-1.1.0\ and release\PartyPicker-1.1.0.zip, `git log origin/main`.

**Cap:** 8 cycles (default; none given). The author asked for this run on 2026-10-31: "please proceed with the
removal and creating the pak and release documentation for the release build. Treat this as a /goal and continue
until the release package is complete."

| Cycle | Work done | Artifacts changed | Verifier verdict |
|---|---|---|---|
| 1 | Plan written and reviewed (proceed after 5 should-fixes, all taken in); Inspiration code, MCM section, tests and channels removed; CPL warning kept party-limit-only in LimitGuard; guard tests added (server section 33, client top, blueprint check in run_tests.py); diff reviewed (ship with changes: 3 doc fixes, made); pak 1.1.0 built from LF export (53,205 bytes, SHA-256 ceeabe02…49b67bc); RUN_CARD 1.1.0 card; dist_docs updated and rendered (docx/pdf, Nexus description, repo README); bundle + zip assembled (zip 736,603 bytes, SHA-256 91dff50a…4b0d3a57) | src, tests, dist_docs, RUN_CARD.md, CLAUDE.md, README.md, PartyPicker.pak, RELEASE_NOTES_v1.1.0.md, release\PartyPicker-1.1.0\, release\PartyPicker-1.1.0.zip | pending |
