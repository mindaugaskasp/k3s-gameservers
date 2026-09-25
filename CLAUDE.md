# Conventions

Hard rules for code, docs and comments.

## Naming

- **A name says what the thing does.** Someone who has never seen this repo must
  understand every function, method and variable from its name alone.
- **No jargon, shorthand or abbreviation** unless it is the domain's own term
  (`A2S`, `ZDOID`, `opcache`). `readPlayerSightings`, not `procPlayers`;
  `lastSeenAt`, not `ls`.
- **The name carries the meaning, not a comment.** Needing a comment to explain
  what a name means is the signal to rename it.
- **Check every name you add or change**, including locals. Renaming now is free;
  a misleading name is read wrong for as long as it survives.

## Structure

- **SOLID, YAGNI, DRY, strictly.** One reason to change per class. Build what is
  needed now, not what might be. Two copies of a rule is one too many.
- **No god classes.** A class file is 200 lines at most; a class that needs more
  is doing more than one job, so split it.
- **Arguments: 3 at most for a function, 4 for a constructor.** More than that is
  a missing type: group them into one.
- **Every new component is recorded in `docs/architecture.md`**: one or two lines
  saying what it does and why it exists. Nothing ships undocumented.
- **Check:** `wc -l` the file you touched, and count the arguments you added.

## Metrics

- **A metric only one game can ever answer carries that game's name**:
  `valheim_world_modifier`, not `game_server_world_modifier`. The name alone has to
  say which server it describes, without reading the exporter to find out.
- **A metric every game answers keeps `game_server_`** and tells the servers apart
  with the `game` label. A prefix there would split one series into three and break
  every query that compares games.
- **A published name is an interface.** Renaming one breaks its Grafana panels and
  the website's readers, so grep `grafana/` and the web repo's `read-game-stats.js`
  first, and change them in the same commit.

## Docs and comments

- **Brief.** Say what it is or what to do. No narratives or incident history
  (git log has those).
- **Links over prose.** Link upstream docs instead of re-explaining them;
  hand-written explanations go stale or wrong.
- **No "why X over Y"** unless it's a technical constraint the reader must
  respect. Skip rationale that offers no fix (e.g. "cause never found").
- **Host-agnostic.** Never name the host's IP, MAC, hostname, hardware,
  capacity or limits. That's an indirect security leak, and the repo must
  work on any host. Host values go in gitignored `.env` files or overrides,
  never in comments.
- **Comments:** 2-3 lines at most.
- **Docs:** 60 lines at most per Markdown file; split by topic. This file is
  exempt: rules live in one place, however long that makes it.
- **Check:** `wc -l *.md docs/*.md` (ignoring CLAUDE.md)
