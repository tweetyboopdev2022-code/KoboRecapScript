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

INBOX="${KOBO_INBOX:-$HOME/Documents/New Kobo Books}"
READY="$INBOX/Ready for Kobo"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="${KOBO_LIBRARY_DIR:-$HERE/library}"
RECAP="${KOBO_RECAP_DIR:-$HERE/pipeline}"
ROOT="${KOBO_STATE_ROOT:-$HOME/kobo-backups}"
STATE="$ROOT/import"
LOGDIR="$ROOT/import-logs"
LOCK="${KOBO_LOCK:-/tmp/kobo_import.lock.d}"
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
BACKUP="$ROOT/originals/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$WORK" "$OUT" "$BACKUP"

say "=== ${#new[@]} file(s) in the inbox"

# audit backs up whatever folder it is handed. After conversion that folder holds
# the converted copy, not the book that arrived, so the originals are backed up
# here instead and $BACKUP stays originals-only. The retire check below reads it.
for f in "${new[@]}"; do
    [ -f "$f" ] && cp -p "$f" "$BACKUP/$(basename "$f")"
done

# Only EPUBs can go through audit. Anything else is converted into the staging
# folder first, and SRCMAP remembers which original produced which staged book so
# a source is never retired on the strength of a sibling's success.
STAGE="$RUN/stage"
CONV="$RUN/converted"
SRCMAP="$RUN/sources.tsv"
mkdir -p "$STAGE" "$CONV"
: > "$SRCMAP"

for f in "${new[@]}"; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$(printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]')" in
    epub)
        cp -p "$f" "$STAGE/$base"
        printf '%s\t%s\n' "$base" "$base" >> "$SRCMAP"
        ;;
    pdf)
        meta=$(python3 "$SKILL/pdf_route.py" --meta --quiet "$f" 2>> "$LOG") || meta=""
        route=$(printf '%s' "$meta" | cut -f1)
        ptitle=$(printf '%s' "$meta" | cut -f2)
        pauthor=$(printf '%s' "$meta" | cut -f3)
        [ -n "$ptitle" ]  || ptitle="${base%.*}"
        [ -n "$pauthor" ] || pauthor="Unknown"
        case "$route" in
            reflow) conv=pdf2epub.py ;;
            fixed)  conv=pdf2kepub.py ;;
            *) say "could not inspect $base, leaving it in the inbox"; continue ;;
        esac
        # A PDF carries no metadata worth trusting. These two are required by the
        # converters, they are a starting point for research, and they are logged
        # so a wrong one is visible rather than silently shipped.
        say "$base -> $conv"
        say "  title  '$ptitle'"
        say "  author '$pauthor'   (derived from the PDF, check it)"
        d="$CONV/${base%.*}"
        mkdir -p "$d"
        if python3 "$SKILL/$conv" "$f" --out "$d" --title "$ptitle" --author "$pauthor" >> "$LOG" 2>&1; then
            for out in "$d"/*.epub; do
                [ -f "$out" ] || continue
                ob=$(basename "$out")
                cp -p "$out" "$STAGE/$ob"
                printf '%s\t%s\n' "$base" "$ob" >> "$SRCMAP"
            done
        else
            say "  conversion failed, leaving $base in the inbox"
        fi
        ;;
    *)
        say "no converter wired up for $base, leaving it in the inbox"
        ;;
    esac
done

staged=$(find "$STAGE" -name '*.epub' -type f | wc -l | tr -d ' ')
if [ "$staged" -eq 0 ]; then
    say "nothing could be staged, stopping"
    exit 0
fi
say "$staged book(s) staged for the build"

if ! python3 "$SKILL/pipeline.py" audit "$STAGE" --work "$WORK" --backup "$RUN/stage-backup" >> "$LOG" 2>&1; then
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
# books forever. But a backup is not evidence the book was built: a PDF is backed
# up, listed by audit as needing conversion, and then never touched again. The
# earlier version retired it anyway, so dropping a PDF in the inbox made it
# vanish having produced nothing. A source now leaves only if it is a key in the
# plan the build actually consumed.
# A converted source is a key in the plan under its STAGED name, not its own, so
# the check goes through SRCMAP rather than matching the original filename.
any_staged_in_plan() {
    [ -f "$SRCMAP" ] || return 1
    local staged_name
    while IFS=$'\t' read -r src staged_name; do
        [ "$src" = "$1" ] || continue
        in_plan "$staged_name" && return 0
    done < "$SRCMAP"
    return 1
}

in_plan() {
    [ -f "$WORK/plan.json" ] || return 1
    python3 - "$WORK/plan.json" "$1" <<'PY'
import json, sys
try:
    plan = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
sys.exit(0 if isinstance(plan, dict) and sys.argv[2] in plan else 1)
PY
}

IMPORTED="$INBOX/Imported"
mkdir -p "$IMPORTED"
retired=0
for f in "${new[@]}"; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    if [ ! -f "$BACKUP/$base" ]; then
        say "no backup of $base, leaving it in the inbox"
    elif [ "$moved" -eq 0 ]; then
        say "nothing reached Ready for Kobo, leaving $base in the inbox"
    elif ! any_staged_in_plan "$base"; then
        say "$base never entered the build, leaving it in the inbox"
    else
        mv "$f" "$IMPORTED/$base" && retired=$((retired+1))
    fi
done
say "$retired original(s) moved to Imported"

say "done. Report: $OUT/REPORT.md"
