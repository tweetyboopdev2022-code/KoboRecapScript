# Kobo Recap System Usage Instructions

## Overview

This system allows you to generate AI-enhanced recaps for your Kobo books, creating dynamic content that's specific to each book rather than hardcoded examples.

## Setup Process

### 1. Prepare Your Environment

First, make sure you have the required tools installed:
- Local LLM tool (llama-cli, ollama, or candle)
- Bash 4+
- Unzip utility
- Pandoc (optional but recommended)

### 2. Configure AI Tools

Run the configuration script to select your preferred AI tool:

```bash
./scripts/ai_config_prompt.sh
```

This will prompt you to select:
1. llama-cli (llama.cpp)
2. ollama 
3. candle (Rust-based LLM)
4. Custom API endpoint
5. Skip AI processing (use generic recaps)

### 3. Set Up Your Book Directories

The system needs to know where your books are stored and where to save the processed files.

Example paths:
- Books directory: `/path/to/your/books/`
- Output directory: `/path/to/output/directory/`

## Processing Individual Books

To process a single book with AI enhancement:

```bash
./scripts/prepare_book_for_recap_ai.sh "Book Title - Author.kepub.epub"
```

The system will:
1. Extract content from your EPUB file
2. Analyze the book using your selected AI tool
3. Generate story-specific recap information
4. Create an enhanced EPUB file with the recaps embedded

## Processing Multiple Books

To process all books in your directory:

```bash
./scripts/prepare_book_for_recap_ai.sh --all
```

This will process every `.kepub.epub` file in your books directory.

## File Structure

The system creates the following structure:
- `~/.kobo_recap_paths`: Stores your book and output directory paths
- `~/.kobo_recap_ai_config`: Stores your AI tool configuration
- Generated EPUB files with `_with_ai_recaps` suffix in your output directory

## Important Notes

1. **AI Tool Requirements**: You must have a local LLM tool installed for AI features to work
2. **File Permissions**: Ensure the system has read/write access to your book directories
3. **Storage Space**: Processed books will be larger than original files due to embedded recaps
4. **macOS Compatibility**: The system is now compatible with macOS grep limitations

## Troubleshooting

### Common Issues

1. **grep -P compatibility errors**: The system automatically handles macOS compatibility now
2. **AI connection failures**: Verify your AI endpoint is accessible and the model is running
3. **File path errors**: Ensure directory paths are correct and have proper permissions

### Testing Your Setup

To verify everything works:

1. Test your AI connection:
   ```bash
   ./scripts/ai_config_prompt.sh
   ```

2. Run a simple test book processing:
   ```bash
   ./scripts/prepare_book_for_recap_ai.sh "Test Book - Author.kepub.epub"
   ```