#!/bin/bash

# Simple verification to check if there's actually content in those files
echo "=== Content Verification ==="
echo ""

if [ $# -eq 0 ]; then
    echo "Usage: $0 \"/full/path/to/Book Title - Author_with_ai_recaps.kepub.epub\""
    exit 1
fi

BOOK_PATH="$1"

# Validate that the file exists
if [ ! -f "$BOOK_PATH" ]; then
    echo "Error: Could not find $BOOK_PATH"
    exit 1
fi

echo "Checking book: $(basename "$BOOK_PATH")"
echo ""

# Create temporary directory for extraction
TEMP_DIR="/tmp/recap_verify_$$"
mkdir -p "$TEMP_DIR"

echo "Extracting book content..."

# Copy the book to working directory
cp "$BOOK_PATH" "$TEMP_DIR/original.kepub.epub"

# Navigate to working directory and unzip
cd "$TEMP_DIR"
unzip -q original.kepub.epub

echo ""
echo "=== FILE SIZES ==="
ls -la "EPUB/recaps/"

echo ""
echo "=== CONTENT CHECK ==="
if [ -f "EPUB/recaps/recaps.tsv" ]; then
    echo "recaps.tsv content:"
    echo "=================="
    cat "EPUB/recaps/recaps.tsv"
else
    echo "No recaps.tsv file found!"
fi

echo ""
if [ -f "EPUB/recaps/cast.tsv" ]; then
    echo "cast.tsv content:"
    echo "================="
    cat "EPUB/recaps/cast.tsv"
else
    echo "No cast.tsv file found!"
fi

echo ""
echo "=== CLEANING UP ==="
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo "Verification complete."