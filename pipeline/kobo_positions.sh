#!/usr/bin/env bash
# Save and restore reading positions around any write to a book on the device.
#
# Rewriting a book file makes Nickel re-import it on the next eject, which
# clears ChapterIDBookmarked and ___PercentRead for that book. That has cost
# real progress twice, so nothing should touch a book on the device without
# save first and restore after the reboot.
#
#   kobo_positions.sh save      before touching any book file
#   kobo_positions.sh restore   after the eject and reboot
#   kobo_positions.sh show      what the device currently thinks
set -uo pipefail

V=/Volumes/KOBOeReader
DB="$V/.kobo/KoboReader.sqlite"
STORE="$HOME/Documents/kobo-db-backups"
PENDING="$STORE/pending-positions"

mounted() { mount | grep -q KOBOeReader || { echo "Kobo is not mounted."; exit 1; }; }

case "${1:-show}" in
save)
    mounted
    mkdir -p "$STORE"
    snap="$STORE/positions-$(date +%Y%m%d-%H%M%S).sqlite"
    sqlite3 "$DB" ".backup '$snap'" || { echo "snapshot failed"; exit 1; }
    printf '%s\n' "$snap" > "$PENDING"
    n=$(sqlite3 "$snap" "select count(*) from content where ContentType=6 and ___PercentRead between 1 and 99;")
    echo "saved $n in-progress book(s) -> $(basename "$snap")"
    ;;
restore)
    mounted
    [ -f "$PENDING" ] || { echo "nothing pending."; exit 0; }
    snap=$(cat "$PENDING")
    [ -f "$snap" ] || { echo "snapshot $snap is gone."; exit 1; }
    cp "$DB" "$STORE/before-restore-$(date +%Y%m%d-%H%M%S).sqlite"
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

-- A re-imported book keeps its percentage but is flagged as never started, so
-- the library lists it as unread with a progress bar. The guard above skips
-- those rows because they were not wiped, so correct the flag separately.
UPDATE content SET FirstTimeReading = 'false'
WHERE ContentType = 6 AND ___PercentRead BETWEEN 1 AND 99
  AND FirstTimeReading = 'true';

PRAGMA wal_checkpoint(TRUNCATE);
SQL
    sync
    rm -f "$PENDING"
    "$0" show
    ;;
show)
    mounted
    sqlite3 -separator "  " "$DB" \
      "select ___PercentRead || '%', replace(ChapterIDBookmarked, rtrim(ChapterIDBookmarked, replace(ChapterIDBookmarked,'!','')), ''), \
       replace(ContentID,'file:///mnt/onboard/','') from content \
       where ContentType=6 and ___PercentRead between 1 and 99 order by DateLastRead desc;"
    [ -f "$PENDING" ] && echo && echo "NOTE: a restore is still pending from $(basename "$(cat "$PENDING")")"
    ;;
*)
    echo "usage: $0 [save|restore|show]"; exit 1 ;;
esac
