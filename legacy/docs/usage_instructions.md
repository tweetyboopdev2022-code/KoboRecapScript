# Usage Instructions

## Setting Up Your Environment

1. **Clone the GitHub repository** to your local machine:
   ```bash
   git clone https://github.com/tweetyboopdev2022-code/KoboRecapScript.git
   ```

2. **Ensure your books are in the correct location**:
   ```
   $HOME/kobo-backups/FULL-20260828-145749/books/
   ```

## Processing a Book

### Simple Command:
```bash
cd ~/sites/mods/kobo-recap-system/scripts/
./prepare_book_for_recap.sh "Book Title - Author.kepub.epub"
```

### Example with Charlotte's Web:
```bash
cd ~/sites/mods/kobo-recap-system/scripts/
./prepare_book_for_recap.sh "Charlotte's Web - E. B. White.kepub.epub"
```

## Batch Processing

### Process All Books:
```bash
cd ~/sites/mods/kobo-recap-system/scripts/
./prepare_book_for_recap.sh --all
```

### Process Books Using Regex Patterns:
```bash
# Process all kepub files
./prepare_book_for_recap.sh "*.kepub.epub"

# Process books with specific pattern
./prepare_book_for_recap.sh "Book*Author*.kepub.epub"

# Process specific books
./prepare_book_for_recap.sh "Book1.kepub.epub" "Book2.kepub.epub"
```

## AI-Enhanced Processing

For enhanced recap generation using local LLMs:

```bash
cd ~/sites/mods/kobo-recap-system/scripts/
./prepare_book_for_recap_ai.sh "Book Title - Author.kepub.epub"
```

### Using Your Own Local LLM:
The AI script automatically detects these local LLM tools:
- Llama CLI
- Ollama 
- Candle

To use your own local LLM, simply install it and modify the AI script to integrate with your specific API.

## Resetting Paths

If you need to change your book or output directories, remove the cached paths:
```bash
rm ~/.kobo_recap_paths
```

## Resetting Progress

To reset progress on batch processing:
1. Remove the cached paths file: `rm ~/.kobo_recap_paths`
2. Run the script again - it will prompt for directory paths

## Copy Result to Kobo:

1. The recap-enabled books are saved to your specified output directory
2. Copy these files to Google Drive/My Drive/Rakuten Kobo
3. Sync to your Kobo device
4. Open in Kobo reader to see recap data

## Security & Privacy

- **No Books Uploaded**: Your actual kepub files never leave your local machine
- **GitHub Only**: Scripts and data are stored in GitHub for backup only
- **Local Processing**: All operations happen on your computer

## Files That Should Be in GitHub:
- `scripts/prepare_book_for_recap.sh` - The main processing script
- `scripts/prepare_book_for_recap_ai.sh` - The AI-enhanced processing script
- `docs/usage_instructions.md` - Documentation

## Files That Stay Local:
- Your actual kepub books in `$HOME/kobo-backups/FULL-20260828-145749/books/`
- Generated recap-enabled books (created during processing)