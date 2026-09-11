---
name: kobo-library
description: "Turn a folder of sideloaded e-books into a library that reads correctly on a Kobo: audit and back up, research the missing metadata, split omnibuses, fix covers and tables of contents, convert to kepub, and embed spoiler-free per-chapter recaps. Use for importing new books, repairing an existing library, converting PDF/azw3/mobi/fb2, writing series into the device database, or generating recaps. Never rewrite a book already on the device without saving reading positions first."
---

# Kobo library

Sideloaded e-books arrive with metadata that ranges from sloppy to actively wrong: authors credited to the wrong person, box sets masquerading as single novels, series positions off by one, no series information at all, descriptions consisting of the literal text `<p>`, Calibre's generated placeholder standing in for the cover, and someone else's library settings baked into the file. This skill turns a folder of such files into a library that reads correctly on a Kobo.

Two things make this harder than it looks, and both are covered in `library/kobo-facts.md`. Read that file before touching a device:

- **A Kobo reads a book's metadata exactly once**, when it first sees the file. Editing the file afterwards and copying it back changes nothing on screen.
- **A Kobo ignores series information inside sideloaded files entirely** unless the NickelSeries mod is installed. Series has to be written into the device's own database.

## Where the scripts are

Everything is in this repo, and the two halves do different jobs:

| folder | what it holds |
|---|---|
| `library/` | the library toolchain: audit, split, metadata, covers, TOC, kepub conversion, device database |
| `pipeline/` | the recap generator, the batch runner, and position save/restore |

`library/pipeline.py` is the entry point the rest hangs off. Run these on the
user's machine, against their folders. Staging into a container is for a step
that genuinely needs something only the container has.

`kobo_import.sh` finds both halves relative to its own location, so a clone
runs without editing paths. `KOBO_LIBRARY_DIR` and `KOBO_RECAP_DIR` override
that if the two ever live apart again.

## One book, or a folder: the whole way through

```bash
pipeline/kobo_import.sh
```

It reads `~/Documents/New Kobo Books`, backs the originals up, audits, researches
against Open Library, builds, embeds recaps **last**, and leaves finished kepubs
in `Ready for Kobo`. Recaps are last because `apply_metadata`, `kepubify` and
`slim` each repackage the archive and would drop `EPUB/recaps/`.

It deliberately does **not** copy to the Kobo. A rewrite on the device costs a
reading position, and that has to be a decision, not a side effect.

## Run the pipeline, not the steps

```bash
python3 library/pipeline.py audit <inbox> --work <dir> --backup <dated dir>
# ... research fills in plan.template.json and any *.split.json ...
python3 library/pipeline.py build <dir> --plan plan.json --out <dir>
```

`audit` backs the originals up, scans every file, drafts a split plan for anything that is really an omnibus, checks the covers, lists anything that is not an EPUB, and writes **`plan.template.json`** - one entry per book with whatever the file already claims filled in and the rest blank.

`build` splits, writes metadata, repairs thin tables of contents, renames from the finished metadata, converts to kepub, verifies that not one character of text changed, resamples oversized images to the panel, and promotes a real jacket over any placeholder cover it can replace from inside the file. **Its output folder is finished** - there is no second slimmed copy to keep in step.

## Nothing survives one shell call - design for that

Every `device_bash` call on the user's machine is reaped when it returns, and `nohup` and `setsid` do not save a background job. A forty-book build or a 200-page render will not finish in one call. Everything long therefore resumes from disk, and **the response to an interrupted run is to issue the identical command again**:

- `pipeline.py build` records finished stages and exits 2 saying what is left. `--slim-seconds 120` makes it stop cleanly rather than be killed mid-book.
- `pdf2kepub.py --render-dir DIR --render-chunk N` renders in slices into a directory that outlives the call.
- `pdfbatch.py --plan jobs.json --seconds 95` drives a whole folder of PDFs the same way, staying on one book until it finishes so completed books arrive early.

Three traps, each of which cost a rebuild:

- **Rename in the staging folder, before conversion.** The resume check asks whether `<staged name>.kepub.epub` exists in the output; renaming the output afterwards makes that check miss and rebuilds everything under the old name, leaving every book in the folder twice.
- **Guard the copy-in step with recorded state, not a presence check.** "Is this file already staged?" stops being true the moment the staged copies are renamed.
- **A file left half-written by a reaped run still exists.** A resume check that only asks whether the file is there accepts a truncated PNG and fails later with "image file is truncated". Check for the closing IEND chunk instead.

The VM disk is around 10 GB, so delete each book's rendered pages once its book exists - nine graphic novels leave 1.8 GB behind otherwise. `pdfbatch.py` does this itself.

## Research: the script first, then one seeded agent

`pipeline/research_kobo.py <plan.template.json>` fills what Open Library can
answer on its own. It only ever **fills empty fields** - it does not overwrite
what the file already claims - recovers a series from filenames shaped
`Series 03 - Title`, prefers the English record where a work lists several, and
only moves a date backwards when it has a sourced year to move it to. Run it
before spending an agent on anything.

What it cannot do is judgement: prequel numbering, companion volumes, a series
baked into the title. That is what the agent is for, on the gaps that are left.



**Researched metadata goes straight into `plan.template.json` on disk and never travels through the conversation.** A subagent that returns JSON for you to retype pays for every description twice.

**Use one agent for the batch, not one per series.** A subagent costs roughly **45,400 tokens before it does anything**, plus about **940 per web call** (measured over 8 runs, R²=0.93). Fanning a 40-book batch across six agents spends a quarter of a million tokens on startup alone.

Seed it hard. Anything you can state confidently - series names and numbering, author sort forms, title cleanups - goes in the prompt as an instruction to apply directly, marked as needing no lookup. Name the genuine gaps explicitly ("these ten dates are broken", "these eleven descriptions are empty") and cap total web calls. Give the agent:

- the path to `plan.template.json` and any `*.split.json`, and an instruction to **edit them in place** with a script and reply with only a one-line count
- this lookup order, stopping at the first source that answers: **Open Library work JSON** → **Google Books** → Wikipedia for series ordering only
- **no cross-checking unless two sources disagree**
- **ISBN only if the first lookup hands one over.** Chasing ISBNs across retailers is the most expensive and least reliable part of this work.

Then check the file yourself before building: every entry filled, every series numbered, no `0101-01-01` dates. Two things the seed gets wrong often enough to look for every time: a **reprint's date standing in for first publication** (a classic dated 2021, or a bare `2012` that is not a valid date at all), and **the series baked into the title** ("Fourth Wing (The Empyrean)") when it belongs in the series field.

**Series order is the one thing worth verifying independently.** It becomes the filename the user sorts by, and a wrong number puts a book after its own sequel. Do not trust your own recollection over sourced research - and where the books themselves carry the publisher's line-up (the "read the whole series" page in the back of the newest volume), render that page and read it. That is a source no catalogue can outrank.

Where a judgement call is needed - how to number prequels, whether a companion volume belongs in the sequence - make the call, and say which call you made and why.

**Filenames keep the whole thing: full series name, full title, no abbreviating, however long it runs.** This is the user's standing preference.

## Recaps

A per-chapter summary and a cast list, written into the book itself and shown by
the [RecapMod](https://github.com/tweetyboopdev2022-code/RecapMod) plugin. Read
`README.md` for the file format and what the model gets wrong; the rules that
matter while running it:

- **Key on the spine path, never on an index.** Nickel's `VolumeIndex` counts
  front matter, so any index the generator invents is off by one against the
  device.
- **Recaps run last**, after every step that repackages the archive.
- **Spoiler control is a display concern as much as a prompt concern.** The
  device cuts at the reader's position inside the chapter, not at the chapter
  boundary, and strips outcome language before showing a description. Do not
  move that logic into the prompt and call it solved.
- A book with no chapter long enough to summarise - a comic, a picture book - is
  left untouched rather than filled with noise.

```bash
python3 pipeline/gen_recaps.py in.kepub.epub out.kepub.epub
pipeline/batch_recaps.sh stage|run|install|restore     # a whole library
python3 pipeline/rebuild_from_raw.py                   # repair without the model
```

`RECAP_ENDPOINT` points the generator at an Ollama host; it defaults to
localhost.

## Books that are not EPUBs

`audit` only ever sees EPUBs and does not convert anything. **`kobo_import.sh`
converts PDF, AZW3, MOBI and FB2 on the way in**, so audit is handed EPUBs and
nothing falls out of the batch - two Cormoran Strike novels went missing that
way, and the importer used to repeat the trick by retiring an unconverted file
to `Imported/` as though it had been built.

- **A PDF**: `pdf_route.py` decides. Median characters a page at or above 1200
  means a novel, so `pdf2epub.py`, reflowed; below that it is a picture book or
  a comic, so `pdf2kepub.py`, fixed-layout. Getting this wrong is not cosmetic
  either way: 900 fixed page images on a six-inch screen cannot change their
  font size, and a picture book reflowed into text loses the book. A scan with
  no text layer reads as 0 characters and routes to fixed-layout, which is
  right - there is nothing to reflow until someone OCRs it.
- **`.azw3` / `.mobi`**: `mobi2epub.py`. KF8 is an EPUB in another wrapper and
  carries its own metadata, so unlike a PDF there is nothing to guess. An older
  MOBI 6 has no KF8 part and unpacks to loose HTML; it fails and says so rather
  than staging something broken. Needs `pip3 install --user mobi`, and PyPI does
  work from the user's machine even though image and binary downloads do not.
- **`.fb2`**: `fb2epub.py <in.fb2> <out.epub>` - positional, not `--out`, unlike
  everything else here. Confirm the word count survives, against the source's own
  text minus its base64 `<binary>` blocks. `.fb2.zip` is **not** handled; the
  glob does not match it and nothing unpacks it.

Rendering needs poppler (`pdftoppm`, `pdfinfo`) or **pymupdf**, and only pymupdf
is installed on the Mac. `pdf2kepub.py` falls back to it automatically, single
process, so `--render-chunk` rather than `--render-jobs` is what keeps a long
book inside one call there.

**A converted book usually has no author sort name**, because `opf:file-as` is
absent from what FB2 and KF8 produce, and `verify_epubs` blocks the build over
it. `research_kobo.py` derives it before deciding whether it needs the network
at all, since that is a transformation of what is there rather than a lookup.
The surname takes any particle with it, so "Ursula K. Le Guin" sorts under Le
Guin rather than Guin, at the cost of writing "de Maupassant, Guy" where a
French library writes "Maupassant, Guy de". Consistency was worth more than
per-language correctness the name alone cannot reveal.

**A PDF's title and author are a guess and must be treated as one.** Both
converters require them, so `pdf_route.py --meta` takes the file's embedded pair,
strips the catalogue noise (`Pendergrass, Daphne, author` becomes
`Daphne Pendergrass`) and falls back to the filename. The importer logs both
under "derived from the PDF, check it". `research_kobo.py` will not correct
them - it only fills blanks - so a wrong one survives all the way to the device
unless somebody reads the log.

Before converting any PDF, check whether it is really one book: `plan_omnibus.py <file.pdf>` reports page-number restarts and running-head changes. A PDF bundle has no manifest to give it away, so nothing else will catch it.

### Reflowing a scanned novel

Measure the OCR before trusting it - not the character count, which only proves *something* is there, but the share of tokens that look wrong (no vowel, case flip mid-word, tripled letter). Under about 0.1% is very good and worth reflowing; the garbage will be confined to display type.

What that means in practice, and it is consistent across scans: **body text OCRs cleanly and every ornamental heading does not.** So chapter numbers are numbered in sequence rather than parsed (one book reported two chapter 12s, a chapter 1 in the middle, and no 13), a chapter whose heading OCR could not read at all is supplied by hand with `--chapter-at PAGE`, and **part dividers are not detected at all** - they are pages of ornament, and numbering the two you can find prints "Part One" over what is really Part Three. No parts beats wrong parts.

Italics are usually unrecoverable and it is worth checking rather than assuming: if the text layer's font is `GlyphLessFont`, it is an invisible OCR overlay carrying no font information, and emphasis is simply gone. Say so when handing the book over.

Paragraphs come from the **right** margin, not the left - every line of a justified paragraph but its last reaches the margin - and the margins must be measured **per page**, because a photographed book sits differently under the camera on every page. A margin averaged over a chapter matches no page in it and yields a book of one-line paragraphs.

## Never trade a good thing for a worse one

`rebuild_toc.py` derives a table of contents from spine headings. A play, a graphic novel, or any book marking chapters with styled paragraphs yields none - and the naive version wrote its **empty** result over a perfectly good 14-entry TOC. It now refuses unless the rebuild has strictly more entries than the book already had.

The same invariant belongs in every repair script here, and two more bugs of exactly this shape have been fixed: `epubmeta.py` defaulted a blank series position to `1`, so an unnumbered companion volume became "book 1" and displaced the real one; `slim.py` dropped a stylesheet that was linked from the XHTML but absent from the OPF manifest. **A repair that cannot improve on what is there must leave it alone, and a default must never invent a fact.** Check the before-and-after count, not just that the step ran.

## Covers

`check_covers.py` flags missing, undersized, wrong-shaped and shared cover art, typographic covers this toolchain generated earlier, and known filler by perceptual hash. With `--fix` it promotes the best real jacket already inside the file.

When a format declares its cover explicitly - FB2's `<coverpage>`, an OPF `<meta name="cover">` - read it. Guessing (first image, largest id, anything containing "cover") picks up an 18x18 ornament, because these formats store images in no useful order.

`build` now does this for itself: it asks `check_covers.py --list-missing` which
books have nothing to promote, and passes exactly those to `apply_metadata.py
--cover-for`. "Missing" means no cover declared and nothing usable inside, never
merely a poor one - generating over a real jacket trades a photograph for
typography. The generated file lands as `cover_generated.jpg`, which
`check_covers.py` recognises later and keeps flagging as wanting a real jacket.

**Do not pass a generated cover off as the real one when reporting back.**

## Sizes, measured

- `slim.py` resamples anything larger than the panel (1072x1448 on a Clara Colour). Its 0.3 MB floor exists because rewriting a book makes the device re-import it and lose that book's reading position.
- Colour comics: quality 65 gives about 39 MB a book against 51 at the default, and is indistinguishable at 1:1 - the Kaleido colour layer is only ~150 dpi. **PNG-8 is far worse** (95 MB) because scans carry JPEG noise rather than flat colour. Compare crops at 1:1 before choosing; do not reason about it from first principles.
- Fixed-layout books are skipped by `slim.py`: for a picture book the image is the page.

## Known environment limits - do not rediscover these

- **Binary and image downloads are blocked.** github.com and the GitHub API are gated; covers.openlibrary.org, books.google.com and author sites are refused by the egress proxy from both the container and the user's machine. Replacement jackets come from inside the file or from the user's browser. **PyPI does work** from her machine.
- **kepubify the binary is therefore unavailable.** `kepubify.py` does the same koboSpan transform in Python; run it with `--verify`.
- **Deleting a file on the user's machine needs permission first** - `rm` fails with "Operation not permitted" until `device_request_delete_permission` is granted for that folder. Ask for it rather than reporting that deletion is impossible.

## Verify, then hand over

`build` runs `kepubify.py --verify`, `verify_epubs.py` and `check_covers.py`, and writes `REPORT.md`.

A text mismatch blocks the batch. So does any book that came out with less than it went in with - fewer TOC entries, a missing stylesheet, a lost image - so compare against the source whenever a stage rewrites a file. **Look at the finished filenames too**, not just the exit codes; two of the three bugs above were invisible in every report and obvious in a directory listing.

For fixed-layout output, render a contact sheet and actually view first, interior and last pages. Automated cropping and spread-splitting get most cases right and a few wrong, and the wrong ones are obvious to an eye and invisible to a checksum.

**Distinguish clearly between problems you introduced and problems that were already in the source.**

## Back up before editing - but not on the Kobo

Pass `--backup` to `audit`. A backup folder on the Kobo drive gets indexed as a second copy of every book, hidden folder or not.

Before anything rewrites books already on the device, save the positions:

```bash
pipeline/kobo_positions.sh save      # Kobo plugged in, before the write
pipeline/kobo_positions.sh restore   # after the device has rebooted
```

A rewritten file is re-imported on the next eject and loses its place. `save`
snapshots `ChapterIDBookmarked`, `___PercentRead` and `ReadStatus`; `restore`
puts them back and clears the never-started flag that otherwise leaves a book
listed as unread with a progress bar. It only touches rows the re-import wiped,
so running it twice is safe.

`library/reading_marker.py` does the human-readable version - chapter,
percentage, and a sentence to search for - and is worth keeping for a book you
are about to hand-edit.

## Working with the device

`kobo_db.py` reads and writes `.kobo/KoboReader.sqlite`.

```bash
python3 kobo_db.py <db> --report                 # what the device thinks it has
python3 kobo_db.py <db> --plan meta.json --apply # series/title/author/shelves
python3 kobo_db.py <db> --prune --apply          # drop entries for missing files
```

It backs the database up first. Read `library/kobo-facts.md` before any device work.

## Tone of the handover

The user is trusting you with their library. Tell them what was actually wrong - the miscredited author, the box set, the series position that would have sorted the book after its own sequel, the Calibre placeholder standing in for a cover - rather than reporting that files were processed. Specifics are what make the work checkable.

The same applies to your own work. When verification catches a bug you introduced, say which books it touched and what you did about it. When you assert something and turn out to be wrong - a series order, whether a PDF was a scan - correct it plainly rather than letting the earlier claim stand. That is the part the user cannot check for themselves.