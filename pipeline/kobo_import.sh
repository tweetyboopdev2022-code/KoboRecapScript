#!/usr/bin/env bash
# Take whatever lands in the inbox all the way to a finished kepub with recaps.
#
#   audit -> research (Open Library) -> build -> recaps -> Ready for Kobo
#
# The log lives OUTSIDE the watched folder on purpose: launchd WatchPaths fires
# on any change to the folder, so writing a log into it makes the job retrigger
# itself every ThrottleInterval, forever.
#
# Recaps run last, on the finished kepub, because apply_metadata, kepubify and
# slim each repackage the archive and would drop EPUB/recaps/.
set -uo pipefail

INBOX="$HOME/Documents/New Kobo Books"
READY="$INBOX/Ready for Kobo"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="${KOBO_LIBRARY_DIR:-$HERE/library}"
RECAP="${KOBO_RECAP_DIR:-$HERE/pipeline}"
STATE="$HOME/kobo-backups/import"
LOGDIR="$HOME/kobo-backups/import-logs"
LOCK=/tmp/kobo_import.lock.d
V=/Volumes/KOBOeReader

for need in "$SKILL/pipeline.py" "$RECAP/gen_recaps.py" "$RECAP/research_kobo.py"; do
    [ -f "$need" ] || { echo "missing: $need" >&2; exit 1; }
done

mkdir -p "$READY" "$STATE" "$LOGDIR"
LOG="$LOGDIR/import-$(date +%Y%m%d).log"

mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

say() { printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG"; }

shopt -s nullglob
new=("$INBOX"/*.epub "$INBOX"/*.azw3 "$INBOX"/*.mobi "$INBOX"/*.fb2 "$INBOX"/*.pdf)
[ ${#new[@]} -eq 0 ] && exit 0

# WatchPaths fires the moment a file appears, which is while a large book is
# still being written. Processing a half-copied archive corrupts the import, so
# wait for every size to hold steady and bail out to the next trigger if not.
sizes_now() { for f in "${new[@]}"; do [ -f "$f" ] && stat -f%z "$f"; done | tr '\n' ' '; }
before=$(sizes_now)
sleep 6
if [ "$before" != "$(sizes_now)" ]; then
    say "files still being written, waiting for the next trigger"
    exit 0
fi

RUN="$STATE/run-$(date +%Y%m%d-%H%M%S)"
WORK="$RUN/work"
OUT="$RUN/out"
BACKUP="$HOME/kobo-backups/originals/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$WORK" "$OUT" "$BACKUP"

say "=== ${#new[@]} file(s) in the inbox"

if ! python3 "$SKILL/pipeline.py" audit "$INBOX" --work "$WORK" --backup "$BACKUP" >> "$LOG" 2>&1; then
    say "audit FAILED, nothing moved"
    exit 1
fi

PLAN="$WORK/plan.template.json"
if [ ! -f "$PLAN" ]; then
    say "audit produced no plan template, stopping"
    exit 1
fi

say "researching against Open Library"
python3 "$RECAP/research_kobo.py" "$PLAN" >> "$LOG" 2>&1
cp "$PLAN" "$WORK/plan.json"

say "building"
python3 "$SKILL/pipeline.py" build "$WORK" --plan plan.json --out "$OUT" >> "$LOG" 2>&1
rc=$?
if [ $rc -eq 2 ]; then
    say "build stopped early with work left; run this again to resume"
    exit 0
elif [ $rc -ne 0 ]; then
    say "build FAILED (rc=$rc), leaving everything in $RUN"
    exit 1
fi

n=0
for f in "$OUT"/*.kepub.epub; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    if unzip -l "$f" 2>/dev/null | grep -q "EPUB/recaps/recaps.tsv"; then
        continue
    fi
    say "recaps: $name"
    tmp=$(mktemp -d)
    if python3 "$RECAP/gen_recaps.py" "$f" "$tmp/$name" >> "$LOG" 2>&1 \
       && [ -f "$tmp/$name" ] && unzip -tqq "$tmp/$name" >/dev/null 2>&1; then
        mv "$tmp/$name" "$f"
        n=$((n+1))
    else
        say "  no recaps produced, book left as built"
    fi
    rm -rf "$tmp"
done
say "recaps embedded in $n book(s)"

moved=0
for f in "$OUT"/*.kepub.epub; do
    [ -f "$f" ] || continue
    mv "$f" "$READY/$(basename "$f")" && moved=$((moved+1))
done
say "$moved book(s) in Ready for Kobo"

if mount | grep -q KOBOeReader; then
    say "Kobo is mounted, but copying is left to you so a rewrite cannot"
    say "cost a reading position unnoticed. Run: batch_recaps.sh install"
fi

# Nothing removed the sources, so every launchd trigger would rebuild the same
# books forever. They move out of the glob only once a backup copy is confirmed.
IMPORTED="$INBOX/Imported"
mkdir -p "$IMPORTED"
retired=0
for f in "${new[@]}"; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    if [ -f "$BACKUP/$base" ]; then
        mv "$f" "$IMPORTED/$base" && retired=$((retired+1))
    else
        say "no backup of $base, leaving it in the inbox"
    fi
done
say "$retired original(s) moved to Imported"

say "done. Report: $OUT/REPORT.md"
