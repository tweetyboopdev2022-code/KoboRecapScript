#!/bin/bash

# Simple preview script for Kobo Recap AI-generated content
echo "=== Simple Kobo Recap AI Content Preview ==="
echo ""

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"/full/path/to/Book Title - Author.kepub.epub\""
    echo ""
    echo "Example:"
    echo "  $0 \"$HOME/Google Drive/My Drive/Rakuten Kobo/Harry Potter 05 - Harry Potter and the Order of the Phoenix - J.K. Rowling_with_ai_recaps.kepub.epub\""
    exit 1
fi

BOOK_PATH="$1"

# Validate that the file exists
if [ ! -f "$BOOK_PATH" ]; then
    echo "Error: Could not find $BOOK_PATH"
    echo ""
    echo "Please check the filename and try again."
    exit 1
fi

BOOK_FILE=$(basename "$BOOK_PATH")
echo "Previewing content for: $BOOK_FILE"
echo ""

# Create temporary directory for extraction
TEMP_DIR="/tmp/recap_preview_simple_$$"
mkdir -p "$TEMP_DIR"

echo "Extracting book content..."

# Copy the book to working directory
cp "$BOOK_PATH" "$TEMP_DIR/original.kepub.epub"

# Navigate to working directory and unzip
cd "$TEMP_DIR"
unzip -q original.kepub.epub

echo ""
echo "=== BOOK STRUCTURE ==="

# Show what files are available in the book
echo "Files found in book structure:"
find . -type f | sort

echo ""
echo "=== CHECKING FOR RECAP DIRECTORIES ==="

# Check if recap directory exists
if [ -d "EPUB/recaps" ]; then
    echo "✓ Recap directory found!"
    echo ""
    echo "Files in recap directory:"
    ls -la "EPUB/recaps"
    
    # Try to show content of TSV files if they exist
    echo ""
    echo "=== CONTENT INSPECTION ==="
    
    if [ -f "EPUB/recaps/recaps.tsv" ]; then
        echo ""
        echo "Chapter Summaries (recaps.tsv):"
        echo "================================"
        head -10 "EPUB/recaps/recaps.tsv"
    else
        echo "No recaps.tsv file found in EPUB/recaps/"
    fi
    
    if [ -f "EPUB/recaps/cast.tsv" ]; then
        echo ""
        echo "Character Profiles (cast.tsv):"
        echo "==============================="
        head -10 "EPUB/recaps/cast.tsv"
    else
        echo "No cast.tsv file found in EPUB/recaps/"
    fi
    
else
    echo "✗ No recap directory found in book structure."
    echo ""
    echo "This may mean:"
    echo "1. The book was processed without AI content"
    echo "2. The book is from an older version of the system"
    echo "3. There were errors during processing that prevented recap creation"
fi

echo ""
echo "=== PREVIEW COMPLETE ==="
echo ""

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo "Preview complete."
echo "The book is ready to be synced to your Kobo device."