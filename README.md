# Kobo Recap System

You put a book down, pick it up weeks later, and cannot remember what happened
or who anyone is. This generates a per-chapter recap and a cast list for a
kepub, writes them into the book itself, and shows them on the device without
revealing anything past where you have read.

The reader side is a separate repo, [RecapMod](https://github.com/tweetyboopdev2022-code/RecapMod),
which draws the page on the Kobo.

## What ends up in the book

Two tab-separated files inside the kepub, under `EPUB/recaps/`:

| file | columns |
|---|---|
| `recaps.tsv` | spine index, spine path, chapter label, summary |
| `cast.tsv` | spine index, spine path, name, role description |

The spine **path** is the key, not the index. Nickel's own `VolumeIndex`
counts front matter, so any index the generator invents disagrees with the
device. Matching the path removes the offset entirely.

`cast.tsv` holds one row per person per chapter they appear in, so the device
can show only what you have already read, and a character's description grows
as their role becomes clearer.

## Running it

Stdlib only, no requirements file. It needs an Ollama endpoint holding a model.

```bash
export RECAP_ENDPOINT=http://your-host:11434/api/generate   # optional
python3 pipeline/gen_recaps.py input.kepub.epub output.kepub.epub
```

A book with no chapter long enough to summarise, a comic or a picture book, is
left untouched rather than filled with noise.

### A whole library

```bash
pipeline/batch_recaps.sh stage     # Kobo plugged in: copy the books off
pipeline/batch_recaps.sh run       # Kobo unplugged: the slow part
pipeline/batch_recaps.sh install   # Kobo plugged in: snapshot, then replace
pipeline/batch_recaps.sh restore   # after the reboot: put the positions back
```

The four phases exist because of one Kobo behaviour: **rewriting a book makes
Nickel re-import it on the next eject, and the reading position is lost.** The
snapshot has to be taken before the write and applied after the reboot, so it
cannot be one command. `pipeline/kobo_positions.sh` does the same job for any
one-off device write, and is worth running before you touch a book by hand.

`pipeline/rebuild_from_raw.py` repairs already-generated books without calling
the model again, using the raw output kept in `raw/`.

## Importing new books

```bash
pipeline/kobo_import.sh
```

Takes everything in `~/Documents/New Kobo Books` all the way to a finished
kepub: back it up, audit it, split anything that is really an omnibus, research
the missing metadata against Open Library, fix covers and the table of contents,
convert, then embed recaps. Finished books land in `Ready for Kobo`; the
originals move to `Imported/` so the next run does not rebuild them.

A PDF is converted on the way in: `pdf_route.py` measures text density and sends
it to `pdf2epub.py` to be reflowed or `pdf2kepub.py` to be photographed. Its
title and author come from the file's own metadata, cleaned, and are logged as
derived - research fills blanks but never corrects a wrong value, so that log
line is the only place a bad one shows up. Other formats are still converted by
hand.

A book that arrives with no cover and nothing usable inside gets a typographic
one generated during the build, which is the normal case for a reflowed PDF. It
is marked as generated so it keeps showing up as wanting a real jacket.

Recaps run **last**, on the finished kepub, because `apply_metadata`, `kepubify`
and `slim` each repackage the archive and would drop `EPUB/recaps/`.

A source file leaves the inbox only once a book it produced is a key in the plan
the build consumed. Anything that failed to convert, or that produced nothing,
stays where it is.

It does not copy anything to the Kobo. A rewrite on the device costs a reading
position, so that step stays manual.

`KOBO_INBOX` and `KOBO_STATE_ROOT` point the whole thing somewhere else, which is
how it gets tested without touching a real library.

## What it gets wrong

Measured over 373 books with `llama3.1:latest`:

- Local models invent relationships. "Uncle Vernon: Harry's mother's brother"
  is wrong and the prompt cannot fully prevent it.
- Non-English books come out mixed. Asking for the chapter's language in the
  prompt did not hold.
- Nicknames were tried and removed. Of five the model produced, two were just
  a token of the name, two were empty, and one belonged to a character who does
  not exist.
- Spoiler control is done at display time as well as in the prompt, because the
  prompt alone is not enough. The device strips outcome language before showing
  a description.

## Layout

| folder | what it holds |
|---|---|
| `library/` | the library toolchain: audit, split, metadata, covers, TOC, kepub conversion, device database |
| `pipeline/` | the recap generator, the batch runner, the importer, position save/restore |
| `legacy/` | the earlier shell implementation, kept for reference only |

`SKILL.md` is the agent-facing version of all of this, and carries the operating
rules the scripts cannot enforce on their own.

`kobo_import.sh` locates both halves relative to its own path, so a clone runs
with no editing. `KOBO_LIBRARY_DIR` and `KOBO_RECAP_DIR` override that.
