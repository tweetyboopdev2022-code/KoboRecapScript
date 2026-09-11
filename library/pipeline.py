#!/usr/bin/env python3
"""Drive the library scripts in the right order, and survive being interrupted.

    python3 pipeline.py audit <inbox> --work <dir> --backup <dated dir>
    python3 pipeline.py build <work> --plan plan.json --out <dir> [--slim-seconds 120]

Two reasons this exists rather than a list of commands in a document.

The order matters and some of it is not obvious: dead spine references have to go
before the table of contents is rebuilt, or the rebuild counts entries that point
at nothing; books have to be renamed BEFORE conversion, because the resume check
asks whether "<staged name>.kepub.epub" exists and renaming afterwards makes that
check miss and rebuild the whole folder under the old name.

And every device_bash call is reaped when it returns, so a forty-book build will
not finish in one. Every stage records what it finished in .pipeline-state.json,
and the response to an interrupted run is to issue the identical command again.
An interrupted build exits 2 and says what is left; a finished one exits 0.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
STATE = ".pipeline-state.json"

# Anything not in here is listed for the operator rather than silently dropped.
# Two Cormoran Strike novels went missing that way.
EPUB = {".epub"}
CONVERTIBLE = {".azw3", ".mobi", ".fb2", ".pdf"}


# --- state -------------------------------------------------------------------
# Presence on disk is not proof a stage ran: a file left half-written by a reaped
# run still exists, and "is this already staged?" stops being true the moment the
# staged copies are renamed. So state is recorded explicitly and separately.

def load_state(d):
    p = Path(d) / STATE
    if p.exists():
        try:
            return json.loads(p.read_text())
        except Exception:
            pass
    return {"stages": {}, "files": {}}


def save_state(d, st):
    p = Path(d) / STATE
    p.write_text(json.dumps(st, indent=1, ensure_ascii=False))


def stage_done(st, name):
    return bool(st["stages"].get(name))


def mark_stage(d, st, name):
    st["stages"][name] = {"at": time.strftime("%Y-%m-%dT%H:%M:%S")}
    save_state(d, st)


def file_done(st, stage, name):
    return name in st["files"].get(stage, [])


def mark_file(d, st, stage, name):
    st["files"].setdefault(stage, [])
    if name not in st["files"][stage]:
        st["files"][stage].append(name)
    save_state(d, st)


# --- running the scripts -----------------------------------------------------

def run(script, *args, capture=False):
    cmd = [sys.executable, str(HERE / script)] + [str(a) for a in args]
    print("  $ %s %s" % (script, " ".join(str(a) for a in args)), flush=True)
    if capture:
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stderr[-2000:], file=sys.stderr)
        return r
    return subprocess.run(cmd)


def have(script):
    return (HERE / script).exists()


def norm_authors(raw):
    """scan_epubs emits [{"name":..,"file_as":..}]; apply_metadata wants pairs."""
    out = []
    for a in raw or []:
        if isinstance(a, dict):
            out.append([a.get("name") or "", a.get("file_as") or ""])
        elif isinstance(a, (list, tuple)):
            out.append([a[0], a[1] if len(a) > 1 else ""])
        else:
            out.append([str(a), ""])
    return out


def first_date(dates):
    """A reprint's date standing in for first publication is the usual error, so
    this only carries the file's claim across - it is not a fact until checked."""
    for d in dates or []:
        d = str(d)[:10]
        if len(d) == 10 and d[:4].isdigit() and not d.startswith("0101"):
            return d
    return ""


def find_isbn(identifiers):
    for i in identifiers or []:
        s = str(i)
        if "isbn" in s.lower():
            tail = s.rsplit(":", 1)[-1].strip()
            if tail.replace("-", "").isdigit():
                return tail
    return ""


def retire(path, work):
    """Get the source EPUB out of the output folder now that the kepub exists.

    Deleting is not available: the user's folders are mounted without it, and rm
    fails with "Operation not permitted". Leaving the source in place is not an
    option either - the folder would carry every book twice, at roughly double
    the size, and verify_epubs would report each book's problems twice over. So
    it moves to a folder beside the work directory, where it can be deleted by
    hand or ignored.
    """
    keep = Path(work) / "_converted-sources"
    keep.mkdir(parents=True, exist_ok=True)
    dst = keep / path.name
    n = 1
    while dst.exists():
        dst = keep / ("%s.%d%s" % (path.stem, n, path.suffix))
        n += 1
    try:
        shutil.move(str(path), str(dst))
        return True
    except OSError as e:
        print("could not move %s out of the output folder: %s" % (path.name, e),
              file=sys.stderr)
        return False


def sound_epub(path):
    """A zip that opens, has its mimetype, and passes its own CRCs.

    The half-written-file trap: checking that the output exists accepts a book
    truncated by a reaped run, and the failure surfaces much later.
    """
    try:
        with zipfile.ZipFile(path) as z:
            if z.testzip() is not None:
                return False
            return any(n.endswith(".opf") for n in z.namelist())
    except Exception:
        return False


# --- audit -------------------------------------------------------------------

def audit(inbox, work, backup):
    inbox, work, backup = Path(inbox), Path(work), Path(backup)
    work.mkdir(parents=True, exist_ok=True)
    backup.mkdir(parents=True, exist_ok=True)
    st = load_state(work)
    notes = []

    files = sorted(p for p in inbox.iterdir() if p.is_file() and not p.name.startswith("."))
    if not files:
        print("Nothing in %s" % inbox)
        return 1

    # 1. Back the originals up before anything reads them, and never onto the
    #    Kobo drive - a backup folder there is indexed as a second copy of every
    #    book, hidden or not.
    if not stage_done(st, "backup"):
        for f in files:
            dst = backup / f.name
            if not dst.exists():
                shutil.copy2(f, dst)
        mark_stage(work, st, "backup")
        print("backed up %d files to %s" % (len(files), backup))

    # 2. Stage into the work folder. Guarded by recorded state, not by asking
    #    whether the file is there.
    if not stage_done(st, "stage"):
        for f in files:
            dst = work / f.name
            if not dst.exists():
                shutil.copy2(f, dst)
        mark_stage(work, st, "stage")

    epubs = sorted(p for p in work.iterdir() if p.suffix.lower() in EPUB)
    others = sorted(p for p in work.iterdir()
                    if p.is_file() and p.suffix.lower() in CONVERTIBLE)

    if others:
        notes.append("Not EPUBs - these need converting before they can go in:")
        for p in others:
            notes.append("  %-60s %s" % (p.name[:60], p.suffix.lower()))

    # 3. Repair before analysis: a spine entry pointing at a file that is not in
    #    the archive would otherwise be counted by the TOC rebuild.
    if epubs and not stage_done(st, "prune") and have("prune_dead_refs.py"):
        run("prune_dead_refs.py", work, "--apply")
        mark_stage(work, st, "prune")

    # 4. What each file actually claims, as opposed to what its name says.
    scan = []
    if epubs:
        r = run("scan_epubs.py", work, "--json", capture=True)
        if r.returncode == 0 and r.stdout.strip():
            try:
                scan = json.loads(r.stdout)
            except Exception as e:
                notes.append("scan_epubs JSON did not parse: %s" % e)
        (work / "scan.json").write_text(json.dumps(scan, indent=1, ensure_ascii=False))

    # 5. Cover and interior-art checks. Both report; neither changes anything here.
    # audit_library.py is deliberately absent here: it compares filenames against
    # metadata, and neither exists yet in a staging folder. It runs at the end of
    # build, where both do.
    for script, args in (("check_covers.py", [work]),
                         ("check_art.py", [work])):
        if epubs and have(script):
            r = run(script, *args, capture=True)
            out = (r.stdout or "").strip()
            if out:
                notes.append("")
                notes.append("--- %s" % script)
                notes.append(out)

    # 6. Omnibus candidates. The analysis is saved for the operator rather than
    #    guessed at: deciding where one novel ends is a judgement call.
    if have("split_omnibus.py"):
        for p in epubs:
            row = next((r for r in scan if r.get("file") == p.name), {})
            spine = row.get("spine") or 0
            size_mb = (row.get("size") or p.stat().st_size) / 1e6
            named = any(k in p.name.lower() for k in
                        ("omnibus", "collection", "trilogy", "quartet", "box set",
                         "boxed set", "complete", "books 1", "volumes", "anthology"))
            # A single novel rarely runs past ~120 spine documents; a text-only
            # file past 3 MB is usually several books rather than one long one.
            if named or (spine > 120 and size_mb > 3):
                r = run("split_omnibus.py", p, "--analyse", capture=True)
                (work / (p.stem + ".analyse.txt")).write_text(r.stdout or "")
                notes.append("possible omnibus: %s  (%s spine docs, %.1f MB) - see %s.analyse.txt"
                             % (p.name, spine or "?", size_mb, p.stem))

    # 7. The template, in the schema apply_metadata.py actually reads: keyed by
    #    filename, authors as [display, sort] pairs, series_index not position.
    notes.append("")
    notes.append("What each file is missing:")
    tmpl_path = work / "plan.template.json"
    tmpl = {}
    if tmpl_path.exists():
        try:
            tmpl = json.loads(tmpl_path.read_text())
        except Exception:
            tmpl = {}
    for p in epubs:
        if p.name in tmpl:
            continue
        row = next((r for r in scan if r.get("file") == p.name), {})
        tmpl[p.name] = {
            "title": row.get("title") or "",
            "authors": norm_authors(row.get("authors")),
            "series": row.get("series") or "",
            "series_index": row.get("series_index") or "",
            "publisher": row.get("publisher") or "",
            "date": first_date(row.get("dates")),
            "language": row.get("language") or "en",
            "isbn": find_isbn(row.get("identifiers")),
            "subjects": row.get("subjects") or [],
            "description": "",
        }
        # What the file is missing, named in the file itself, so the research
        # step is aimed rather than told to look everything up again.
        gaps = [k for k in ("title", "series", "date", "isbn") if not tmpl[p.name][k]]
        if not row.get("description_len"):
            gaps.append("description")
        if any(not a[1] for a in tmpl[p.name]["authors"]):
            gaps.append("author sort")
        if gaps:
            notes.append("  %-58s needs: %s" % (p.name[:58], ", ".join(gaps)))
        for prob in row.get("problems") or []:
            notes.append("  %-58s %s" % ("", prob))
    tmpl_path.write_text(json.dumps(tmpl, indent=1, ensure_ascii=False))

    report = work / "AUDIT.md"
    report.write_text("# Audit\n\n%d EPUBs, %d other files\n\n%s\n"
                      % (len(epubs), len(others), "\n".join(notes)))
    print("\n".join(notes))
    print("\n%d books. Template: %s" % (len(epubs), tmpl_path))
    print("Fill in the blanks, save as plan.json, then run build.")
    return 0


# --- build -------------------------------------------------------------------

def build(work, plan, out, slim_seconds):
    work, out = Path(work), Path(out)
    plan_path = Path(plan) if Path(plan).is_absolute() else work / plan
    if not plan_path.exists():
        print("No plan at %s" % plan_path, file=sys.stderr)
        return 1
    out.mkdir(parents=True, exist_ok=True)
    st = load_state(work)
    started = time.time()

    def out_of_time():
        return slim_seconds and (time.time() - started) > slim_seconds

    # 1. Split anything with a *.split.json beside it, before metadata is written:
    #    the parts are what get the metadata, not the omnibus.
    if not stage_done(st, "split") and have("split_omnibus.py"):
        for sj in sorted(work.glob("*.split.json")):
            src = work / (sj.name[:-len(".split.json")] + ".epub")
            if src.exists():
                run("split_omnibus.py", src, "--plan", sj, "--out", work)
        mark_stage(work, st, "split")

    # 2. Metadata into the output folder. Everything after this works on out/.
    if not stage_done(st, "metadata"):
        # A converted PDF or a stripped sideload can arrive with no cover and
        # nothing inside to promote, and the device then shows a grey rectangle.
        # apply_metadata can draw one, but only for files it is told about.
        cover_for = []
        if have("check_covers.py"):
            c = run("check_covers.py", work, "--list-missing", capture=True)
            if c.returncode == 0:
                cover_for = [ln.strip() for ln in (c.stdout or "").splitlines()
                             if ln.strip()]
        if cover_for:
            print("generating a cover for %d book(s) with none: %s"
                  % (len(cover_for), ", ".join(cover_for)))
        args = [work, "--plan", plan_path, "--out", out]
        for fn in cover_for:
            args += ["--cover-for", fn]
        r = run("apply_metadata.py", *args)
        if r.returncode != 0:
            return 1
        mark_stage(work, st, "metadata")

    # 3. Dead references, then the table of contents. This order is the point:
    #    rebuild_toc refuses unless it can beat what is already there, and it
    #    cannot judge that against a spine full of entries pointing at nothing.
    if not stage_done(st, "prune") and have("prune_dead_refs.py"):
        run("prune_dead_refs.py", out, "--apply")
        mark_stage(work, st, "prune")

    if not stage_done(st, "toc") and have("rebuild_toc.py"):
        run("rebuild_toc.py", out)
        mark_stage(work, st, "toc")

    # 4. Rename BEFORE conversion. Renaming the .kepub.epub afterwards makes the
    #    resume check below miss and rebuild every book under its old name,
    #    leaving the folder holding each book twice.
    if not stage_done(st, "rename"):
        run("rename_files.py", out, "--apply")
        mark_stage(work, st, "rename")

    # 5. Convert, one book at a time so an interrupted run keeps what it finished.
    #    A .kepub.epub that exists is not enough - it has to open.
    pending = [p for p in sorted(out.iterdir())
               if p.suffix == ".epub" and not p.name.endswith(".kepub.epub")]
    for p in pending:
        target = p.with_name(p.stem + ".kepub.epub")
        if file_done(st, "kepub", p.name) and sound_epub(target):
            continue
        if target.exists() and not sound_epub(target):
            target.unlink()
        # kepubify.py's second positional is a DIRECTORY - it derives the output
        # name itself. Passing the intended filename makes a directory of that
        # name, and the book that was converted correctly is then reported as a
        # failure because nothing is at the path we expected.
        r = run("kepubify.py", p, out, "--verify")
        if r.returncode == 0 and sound_epub(target):
            mark_file(work, st, "kepub", p.name)
            retire(p, work)
        else:
            print("conversion failed: %s" % p.name, file=sys.stderr)
            return 1
        if out_of_time():
            return unfinished(out, st)

    # 6. Structural check. A text mismatch or a book that came out with less than
    #    it went in with blocks the batch.
    if not stage_done(st, "verify"):
        r = run("verify_epubs.py", out, "--json", out / "verify.json")
        if r.returncode != 0:
            print("\nverify_epubs reported problems - stopping before slim.", file=sys.stderr)
            print("Most often this is the plan rather than the books: an author "
                  "with no sort name, or a title left blank. Fix %s and run the "
                  "same command again." % plan_path.name, file=sys.stderr)
            return 1
        mark_stage(work, st, "verify")

    # 7. Resample oversized images. slim.py wants a folder, so each book goes
    #    through a scratch folder of its own - that is what makes it stoppable.
    scratch = work / ".slim"
    if have("slim.py"):
        books = [p for p in sorted(out.iterdir()) if p.name.endswith(".kepub.epub")]
        for p in books:
            if file_done(st, "slim", p.name):
                continue
            if out_of_time():
                return unfinished(out, st)
            if scratch.exists():
                shutil.rmtree(scratch)
            scratch.mkdir(parents=True)
            tmp = scratch / p.name
            shutil.copy2(p, tmp)
            run("slim.py", scratch, "--apply")
            if sound_epub(tmp):
                shutil.move(str(tmp), str(p))
                mark_file(work, st, "slim", p.name)
            else:
                print("slim produced an unreadable file for %s - original kept"
                      % p.name, file=sys.stderr)
                mark_file(work, st, "slim", p.name)
        if scratch.exists():
            shutil.rmtree(scratch)

    # 8. Promote a real jacket over a placeholder, from inside the file.
    if not stage_done(st, "covers") and have("check_covers.py"):
        run("check_covers.py", out, "--fix")
        mark_stage(work, st, "covers")

    # 9. Last look: filenames against metadata. Two of three bugs that reached
    #    the library were invisible in every report and obvious in a listing.
    tail = []
    for script in ("check_covers.py", "check_art.py", "audit_library.py"):
        if have(script):
            r = run(script, out, capture=True)
            if (r.stdout or "").strip():
                tail.append("## %s\n\n%s" % (script, r.stdout.strip()))
    (out / "REPORT.md").write_text(
        "# Build\n\n%d books\n\n%s\n" %
        (len([p for p in out.iterdir() if p.name.endswith('.kepub.epub')]),
         "\n\n".join(tail)))

    mark_stage(work, st, "done")
    print("\nFinished. %s" % (out / "REPORT.md"))
    return 0


def unfinished(out, st):
    done = len(st["files"].get("slim", []))
    conv = len(st["files"].get("kepub", []))
    print("\nStopped cleanly with work left: %d converted, %d slimmed."
          % (conv, done), file=sys.stderr)
    print("Run the identical command again to carry on.", file=sys.stderr)
    return 2


# --- entry -------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("audit")
    a.add_argument("inbox")
    a.add_argument("--work", required=True)
    a.add_argument("--backup", required=True)

    b = sub.add_parser("build")
    b.add_argument("work")
    b.add_argument("--plan", default="plan.json")
    b.add_argument("--out", required=True)
    b.add_argument("--slim-seconds", type=int, default=0,
                   help="stop cleanly after this many seconds rather than be killed")

    ns = ap.parse_args()
    if ns.cmd == "audit":
        return audit(ns.inbox, ns.work, ns.backup)
    return build(ns.work, ns.plan, ns.out, ns.slim_seconds)


if __name__ == "__main__":
    sys.exit(main())
