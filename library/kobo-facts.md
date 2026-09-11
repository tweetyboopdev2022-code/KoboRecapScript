# Kobo Facts

## Core Principles

1. **A Kobo reads a book's metadata exactly once**, when it first sees the file. Editing the file afterwards and copying it back changes nothing on screen.

2. **A Kobo ignores series information inside sideloaded files entirely** unless the NickelSeries mod is installed. Series must be written into the device's own database.

## Technical Details

- **Device Database**: `~/.kobo/KoboReader.sqlite`
- **Library Location**: Books are stored in `~/Kobo/` 
- **Metadata Format**: EPUB metadata is read and cached by the device
- **Series Handling**: Series information must be written to the device database, not embedded in books

## File Formats

- **Primary**: EPUB (with kepub conversion)
- **Supported**: AZW3/MOBI (via mobi package)
- **Alternative**: FB2 (via fb2epub.py)
- **Special Cases**: PDF (fixed-layout or reflowed)

## Device Considerations

- **Screen Resolution**: Clara Colour (1072x1448 pixels)
- **Cover Requirements**: 1072x1448 pixels minimum
- **Storage Management**: Files must be properly named and organized

## Workflow Notes

- Always backup originals before processing
- Verify that all metadata changes are correctly applied
- Check that no files are corrupted during conversion
- Validate the final library structure before transferring to device