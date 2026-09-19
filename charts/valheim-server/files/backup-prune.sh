#!/bin/sh
# backup-prune.sh DIR RECENT_DAYS WINDOW_END_DAYS...
# Ages are play time: each backup gets a clock value once, the previous
# one's plus the gap, capped at a day, so idle months age nothing. Kept in
# DIR/.play-clock, which can't be rebuilt once files are gone: if it's
# missing or unreadable while an archive exists, nothing is touched.
# Backups within RECENT_DAYS stay in DIR. Older ones move to DIR/archive if
# newest or oldest in their window (RECENT-7, 7-14, ...), the oldest ageing
# into the next; the rest, and anything past the last window, are deleted.
set -eu
dir=$1; recent=$2; shift 2
clock="$dir/.play-clock"
mkdir -p "$dir/archive"
find "$dir" "$dir/archive" -maxdepth 1 -type f -name '*.zip' -printf '%T@ %p\n' | sort -n |
  awk -v recent="$recent" -v ends="$*" -v clock="$clock" '
    BEGIN {
      while ((r = getline l < clock) > 0) {
        if (l !~ /^[^ ]+ [0-9]+$/) { bad = "unreadable line: " l; break }
        split(l, c, " "); known[c[1]] = c[2]; nknown++
      }
      if (r < 0 && !bad) bad = "missing"
    }
    {
      f = substr($0, index($0, " ") + 1); name = f; sub(/.*\//, "", name)
      if (name ~ / /) next  # the index is space-separated; leave such files alone
      N++; mtime[N] = $1; path[N] = f; base[N] = name
      # New backups land in DIR, so an unindexed archive file means a bad index.
      if (f ~ /\/archive\// && !(name in known) && !bad) bad = "has no entry for " name
      if (f ~ /\/archive\//) archived++
    }
    END {
      NR = N
      if (NR == 0) exit
      if (bad && archived) {
        print "backup-prune: " clock " " bad "; not pruning" > "/dev/stderr"; exit 1
      }
      for (k = 1; k <= NR; k++) {  # oldest first
        if (base[k] in known) p[k] = known[base[k]]
        else if (k == 1) p[k] = 0
        else { gap = mtime[k] - mtime[k - 1]; p[k] = p[k - 1] + (gap < 86400 ? gap : 86400) }
      }
      # Rewritten whole each run, before any file is touched.
      tmp = clock ".tmp"; printf "" > tmp
      for (k = 1; k <= NR; k++) printf "%s %d\n", base[k], p[k] > tmp
      close(tmp)
      while ((getline l < tmp) > 0) written++
      close(tmp)
      if (written != NR || system("mv -f \"" tmp "\" \"" clock "\"")) {
        print "backup-prune: could not write " clock "; not pruning" > "/dev/stderr"; exit 1
      }

      n = split(ends, e, " ")
      for (k = 1; k < NR; k++) {  # never the newest
        age = (p[NR] - p[k]) / 86400
        if (age < recent) continue
        w = 0; lo = recent
        for (i = 1; i <= n; i++) { if (age >= lo && age < e[i]) { w = i; break }; lo = e[i] }
        if (!w) { print "rm " path[k]; continue }
        files[w, ++count[w]] = path[k]
      }
      for (i = 1; i <= n; i++)
        for (j = 1; j <= count[i]; j++)
          print (j == 1 || j == count[i] ? "keep " : "rm ") files[i, j]
    }' |
  while read -r action f; do
    if [ "$action" = rm ]; then rm -fv -- "$f"
    elif [ "${f%/*}" != "$dir/archive" ]; then mv -v -- "$f" "$dir/archive/"
    fi
  done
