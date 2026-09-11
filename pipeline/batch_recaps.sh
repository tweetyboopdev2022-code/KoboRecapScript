#!/usr/bin/env bash
# Generate recap data for every unfinished book on the Kobo.
#
#   stage    Kobo plugged in.  Snapshot the queue and copy the books to books/.
#   run      Kobo unplugged.   Generate into out/. The slow part.
#   install  Kobo plugged in.  Snapshot reading positions, then replace books.
#   restore  Kobo plugged in, AFTER the reboot. Put the positions back.
#
# Replacing a book file makes Nickel re-import it on the next eject, which
# clears ChapterIDBookmarked and ___PercentRead. That happens after install has
# finished, so the positions can only be put back on the following plug-in.
set -uo pipefail
cd "$(dirname "$0")"

V=/Volumes/KOBOeReader
DB="$V/.kobo/KoboReader.sqlite"
BOOKS=books
OUT=out
STATE=state
BACKUP="$HOME/Documents/kobo-book-backups"
DBBACKUP="$HOME/Documents/kobo-db-backups"
QUEUE="$BOOKS/queue.txt"
PENDING="$STATE/pending_restore"

need_device() {
    mount | grep -q KOBOeReader || { echo "Kobo is not mounted."; exit 1; }
}

warn_pending() {
    [ -f "$PENDING" ] && echo "NOTE: a position restore is still pending. Run './batch_recaps.sh restore'."
}

stage() {
    need_device
    warn_pending
    mkdir -p "$BOOKS"
    sqlite3 "$DB" \
        "select ContentID from content where ContentType=6 \
         and DateLastRead is not null and ___PercentRead < 95 order by DateLastRead desc;" \
        | sed 's|^file://||' | sed "s|^/mnt/onboard/||" > "$QUEUE"
    n=0
    while IFS= read -r rel; do
        [ -f "$V/$rel" ] || { echo "skip, not on disk: $rel"; continue; }
        mkdir -p "$BOOKS/$(dirname "$rel")"
        cp "$V/$rel" "$BOOKS/$rel" && n=$((n+1))
    done < "$QUEUE"
    echo "staged $n books, $(du -sh "$BOOKS" | cut -f1) total. The Kobo can be ejected now."
}

stage_all() {
    need_device
    warn_pending
    mkdir -p "$BOOKS"
    : > "$QUEUE"
    n=0; have=0
    find "$V" -name "*.epub" -not -path "*/.kobo/kepub/*" -not -path "*/.kobo/eLabel/*" \
        | sed "s|^$V/||" | sort > "$BOOKS/all.txt"
    while IFS= read -r rel; do
        f="$V/$rel"
        [ -f "$f" ] || continue
        if unzip -l "$f" 2>/dev/null | grep -q "EPUB/recaps/recaps.tsv"; then
            have=$((have+1)); continue
        fi
        printf '%s\n' "$rel" >> "$QUEUE"
        mkdir -p "$BOOKS/$(dirname "$rel")"
        cp "$f" "$BOOKS/$rel" && n=$((n+1))
    done < "$BOOKS/all.txt"
    rm -f "$BOOKS/all.txt"
    echo "staged $n books ($have already have recaps), $(du -sh "$BOOKS" | cut -f1) total."
    echo "The Kobo can be ejected now."
}

run() {
    [ -f "$QUEUE" ] || { echo "nothing staged; run './batch_recaps.sh stage' first"; exit 1; }
    mkdir -p "$OUT"
    d=0; s=0; f=0
    while IFS= read -r rel; do
        src="$BOOKS/$rel"
        name=$(basename "$rel")
        [ -f "$src" ] || { echo "SKIP  not staged: $name"; s=$((s+1)); continue; }
        echo "=== $name"
        if ! python3 gen_recaps.py "$src" "$OUT/$name"; then
            echo "FAIL  generator error: $name"; f=$((f+1)); continue
        fi
        if [ ! -f "$OUT/$name" ]; then
            echo "SKIP  nothing to summarise: $name"; s=$((s+1)); continue
        fi
        if ! unzip -tqq "$OUT/$name" >/dev/null 2>&1; then
            echo "FAIL  corrupt archive: $name"; rm -f "$OUT/$name"; f=$((f+1)); continue
        fi
        d=$((d+1))
        echo
    done < "$QUEUE"
    echo "generated $d, skipped $s, failed $f. Plug the Kobo in and run './batch_recaps.sh install'."
}

install_back() {
    need_device
    mkdir -p "$BACKUP" "$DBBACKUP" "$STATE"

    snap="$DBBACKUP/positions-$(date +%Y%m%d-%H%M%S).sqlite"
    sqlite3 "$DB" ".backup '$snap'" || { echo "could not snapshot the database; aborting"; exit 1; }
    printf '%s\n' "$snap" > "$PENDING"
    kept=$(sqlite3 "$snap" "select count(*) from content where ContentType=6 and DateLastRead is not null;")
    echo "positions snapshotted for $kept books -> $(basename "$snap")"

    c=0
    while IFS= read -r rel; do
        name=$(basename "$rel")
        [ -f "$OUT/$name" ] || continue
        [ -f "$V/$rel" ] || { echo "SKIP  original gone: $name"; continue; }
        cp -n "$V/$rel" "$BACKUP/$name" 2>/dev/null
        if cp "$OUT/$name" "$V/$rel"; then
            c=$((c+1)); echo "OK    $name"
        else
            echo "FAIL  $name"
        fi
    done < "$QUEUE"
    sync
    echo "installed $c books; originals in $BACKUP"
    echo
    echo "NEXT: eject, let it reboot, plug back in, then run './batch_recaps.sh restore'."
}

restore_positions() {
    need_device
    [ -f "$PENDING" ] || { echo "no pending restore."; exit 0; }
    snap=$(cat "$PENDING")
    [ -f "$snap" ] || { echo "snapshot $snap is missing; cannot restore."; exit 1; }

    cp "$DB" "$DBBACKUP/before-restore-$(date +%Y%m%d-%H%M%S).sqlite"
    sqlite3 "$DB" <<SQL
ATTACH DATABASE '$snap' AS old;
UPDATE content
SET ChapterIDBookmarked = (select o.ChapterIDBookmarked from old.content o where o.ContentID = content.ContentID),
    ___PercentRead      = (select o.___PercentRead      from old.content o where o.ContentID = content.ContentID),
    ReadStatus          = (select o.ReadStatus          from old.content o where o.ContentID = content.ContentID),
    DateLastRead        = (select o.DateLastRead        from old.content o where o.ContentID = content.ContentID),
    FirstTimeReading    = (select o.FirstTimeReading    from old.content o where o.ContentID = content.ContentID),
    TimeSpentReading    = (select o.TimeSpentReading    from old.content o where o.ContentID = content.ContentID),
    RestOfBookEstimate  = (select o.RestOfBookEstimate  from old.content o where o.ContentID = content.ContentID),
    adobe_location      = (select o.adobe_location      from old.content o where o.ContentID = content.ContentID)
WHERE ContentType = 6
  AND (DateLastRead IS NULL OR ___PercentRead = 0)
  AND EXISTS (select 1 from old.content o
              where o.ContentID = content.ContentID
                and o.DateLastRead is not null
                and o.___PercentRead > 0);
DETACH DATABASE old;
PRAGMA wal_checkpoint(TRUNCATE);
SQL
    sync
    rm -f "$PENDING"
    echo "restored. positions now:"
    sqlite3 -separator "  ->  " "$DB" \
        "select replace(ChapterIDBookmarked, rtrim(ChapterIDBookmarked, replace(ChapterIDBookmarked,'!','')), ''), \
         ___PercentRead || '%' from content \
         where ContentType=6 and ___PercentRead between 1 and 94 order by DateLastRead desc;"
    echo
    echo "Eject and check a book opens where you left it."
}

case "${1:-}" in
    stage)   stage ;;
    stage-all) stage_all ;;
    run)     run ;;
    install) install_back ;;
    restore) restore_positions ;;
    *)       echo "usage: $0 [stage|stage-all|run|install|restore]"; exit 1 ;;
esac
