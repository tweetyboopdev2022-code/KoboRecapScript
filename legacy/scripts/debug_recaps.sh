#!/bin/bash

# Debug script for Kobo Recap AI issues
# This script helps diagnose why recap files might not be showing up

echo "=== Kobo Recap AI Debug Tool ==="
echo ""

# Check if we have cached paths from previous runs
if [ -f "$HOME/.kobo_recap_paths" ]; then
    source "$HOME/.kobo_recap_paths"
fi

# Get books directory path (ask user if not set)
if [ -z "$BOOKS_DIR" ]; then
    echo "Please specify the directory where your kepub books are stored:"
    echo "(Example: /path/to/your/books/)"
    read -p "Books directory path: " BOOKS_DIR
    # Validate the directory exists
    if [ ! -d "$BOOKS_DIR" ]; then
        echo "Error: Directory '$BOOKS_DIR' does not exist."
        exit 1
    fi
    # Save for future runs
    echo "BOOKS_DIR=\"$BOOKS_DIR\"" > "$HOME/.kobo_recap_paths"
fi

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"Book Title - Author.kepub.epub\""
    echo ""
    echo "Available books in your collection:"
    find "$BOOKS_DIR" -name "*.kepub.epub" -type f | xargs -n1 basename | head -10
    exit 1
fi

BOOK_FILE="$1"

# Validate that the file exists in the expected location
BOOK_PATH="$BOOKS_DIR/$BOOK_FILE"

if [ ! -f "$BOOK_PATH" ]; then
    echo "Error: Could not find $BOOK_FILE in your books directory"
    echo ""
    echo "Available books in your collection:"
    find "$BOOKS_DIR" -name "*.kepub.epub" -type f | xargs -n1 basename | head -10
    echo ""
    echo "Please check the filename and try again."
    exit 1
fi

echo "Debugging content for: $BOOK_FILE"
echo ""

# Create temporary directory for extraction
TEMP_DIR="/tmp/recap_debug_$$"
mkdir -p "$TEMP_DIR"

echo "Extracting book content..."

# Copy the book to working directory
cp "$BOOK_PATH" "$TEMP_DIR/original.kepub.epub"

# Navigate to working directory and unzip
cd "$TEMP_DIR"
unzip -q original.kepub.epub

echo "=== DEBUG INFORMATION ==="
echo ""

echo "Files in the book structure:"
find . -type f | sort | head -20

echo ""
echo "=== CHECKING FOR RECAP DIRECTORIES ==="
if [ -d "EPUB/recaps" ]; then
    echo "Recap directory found!"
    ls -la "EPUB/recaps"
else
    echo "No recap directory found"
fi

echo ""
echo "=== CHECKING FOR AI CONFIGURATION ==="
if [ -f "$HOME/.kobo_recap_ai_config" ]; then
    echo "AI configuration found:"
    cat "$HOME/.kobo_recap_ai_config"
else
    echo "No AI configuration found"
fi

echo ""
echo "=== CHECKING IF THIS IS AN AI-GENERATED BOOK ==="
if [ -f "EPUB/recaps/recaps.tsv" ]; then
    echo "AI recap file exists - content:"
    head -10 "EPUB/recaps/recaps.tsv"
else
    echo "No AI recap file found"
fi

echo ""
echo "=== DEBUG COMPLETE ==="

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "Debug complete. This shows what files are available in your book."
echo "If you want to regenerate the book with AI, try:"
echo "./scripts/prepare_book_for_recap_ai.sh \"$BOOK_FILE\""