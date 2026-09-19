# Conventions

Hard rules for docs and code comments.

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
- **Docs:** 60 lines at most per Markdown file; split by topic.
- **Check:** `wc -l *.md docs/*.md`
