---
name: docu-guard
description: >
  End-of-session documentation pass. Use when the user says /docu-guard,
  "doku nachziehen", "dokumentiere die session", "bevor ich clear mache",
  or asks that the next session knows everything from the docs alone.
  Reviews what this session changed, decided, learned and left open, then
  brings the project's own documentation up to date - Obsidian vault,
  docs/, README, CLAUDE.md / AGENTS.md, handoffs - so /clear loses nothing.
---

# docu-guard

Goal: after this pass, a fresh session that reads only the project's
documentation knows everything this session knew. Nothing lives only in the
chat any more.

Language: follow the project (valiora docs are German, its vault is
English; dotfiles CLAUDE.md is English). Talk to the user in German.

## 1. Collect what happened - from evidence, not memory

Build a short list of what this session actually did. Sources, in this order:

- `git status --short`, `git diff`, `git log --since="<session start>" --stat`
  in every repo touched (`git-all` in ~/Projects shows which have changes).
- Files created or edited outside git (live config, ~/.config, scripts).
- The conversation: decisions and their reasons, things tried that failed,
  numbers measured, commands that verified something, open questions, and
  anything the user said should be remembered ("merk dir", "nie wieder").

For each item note: **what** changed, **why** (the user's reason or the
evidence), **how it was verified**, and **what is still open**. Facts not
verified in the session are marked as such - never promoted to certainty.

## 2. Find where documentation lives in this project

Look, do not assume:

- A documentation guideline: `docs/doku-leitfaden.md`, `docs/README.md`,
  `CONTRIBUTING.md`, a "Docs" section in CLAUDE.md. **If one exists it is
  binding** - it decides where a topic goes, naming, language, and how the
  index is kept. Read it before writing anything.
- An Obsidian vault: a directory with `.obsidian/` (valiora: `docs/vault/`).
  Notes there are atomic, titled in Title Case, linked with `[[Wikilinks]]`,
  with `tags:`/`date:` frontmatter - copy the shape of an existing note.
- `docs/` subfolders (features, guides, technical, handoffs, roadmap,
  research, archive), `README.md`s, `CLAUDE.md`, `AGENTS.md`.
- A related incidents repo (`~/Projects/paulgradischnig/incidents`) for
  real failures - the `incidents` rule already says when to offer one.

If the project has **no** documentation at all, ask before creating a
structure; a single `CLAUDE.md` with a "Current state" section is the
minimum, not a docs tree.

## 3. Route every item to exactly one place

| Item | Goes to |
|---|---|
| Concept, architecture decision, invariant, solved bug and its cause | vault note (extend an existing one first - `grep -ri` the topic) |
| How-to, commands, cheatsheet | `docs/guides/` or the README's setup section |
| Feature spec being built now | `docs/features/<feature>/` |
| Future idea, deferred work | `docs/roadmap/` or an "Open" section - not the vault |
| Rules for how agents should work in this repo, gotchas, "don't do X" | `CLAUDE.md` / `AGENTS.md` |
| Setup, run, deploy of *this* repo | `README.md` |
| "Continue here next time" state | `docs/handoffs/<date>-<slug>.md` - delete or fold into the vault once done |
| A real failure with a cause | offer an incident postmortem (see the incidents rule) |

One home per topic; everywhere else link to it. Extend before you create.
Update the index (`docs/README.md` or equivalent) for every new non-vault
document if the project keeps one.

## 4. Write

- Match the existing style, headings, language and frontmatter exactly.
- Record the **why** and the **evidence** (command + result, measured
  number, upstream issue), not just the what. Dead ends belong in too -
  they save the next session from repeating them.
- Mark unverified claims: "not verified", "assumed".
- Remove or correct documentation the session proved wrong. Stale docs are
  worse than missing ones.
- Delete handoffs whose work is done.
- Never write private data into a repo (IPs, hostnames of private machines,
  credentials, personal e-mail addresses, other projects' contents).

## 5. Verify and hand over

- Re-read each changed doc once as the next session would: can it act on
  this without the chat? If a step needs the chat, the doc is not done.
- `git status --short` per repo; commit the documentation changes with a
  message that names the session's topic (Claude cannot push - say what
  the user has to push, see the git-remote rule).
- Report in German: which files changed, what is now documented where,
  what stayed open, and that the user can `/clear`.
