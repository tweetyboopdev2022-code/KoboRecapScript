#!/bin/bash

echo "=== Kobo Recap AI Content Preview ==="
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
    echo "BOOKS_DIR=\"\$BOOKS_DIR\"" > "$HOME/.kobo_recap_paths"
fi

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: \$0 \"Book Title - Author.kepub.epub\""
    echo ""
    echo "Available books in your collection:"
    find "$BOOKS_DIR" -name "*.kepub.epub" -type f | xargs -n1 basename | head -10
    exit 1
fi

BOOK_FILE="$1"

# Validate that the file exists in the expected location
BOOK_PATH="$BOOKS_DIR/$BOOK_FILE"

if [ ! -f "$BOOK_PATH" ]; then
    echo "Error: Could not find \$BOOK_FILE in your books directory"
    echo ""
    echo "Available books in your collection:"
    find "$BOOKS_DIR" -name "*.kepub.epub" -type f | xargs -n1 basename | head -10
    echo ""
    echo "Please check the filename and try again."
    exit 1
fi

echo "Previewing content for: \$BOOK_FILE"
echo ""

# Create temporary directory for extraction
TEMP_DIR="/tmp/recap_preview_$$"
mkdir -p "$TEMP_DIR"

echo "Extracting book content..."

# Copy the book to working directory
cp "$BOOK_PATH" "$TEMP_DIR/original.kepub.epub"

# Navigate to working directory and unzip
cd "$TEMP_DIR"
unzip -q original.kepub.epub

# Check if recap files exist
if [ -f "EPUB/recaps/recaps.tsv" ] && [ -f "EPUB/recaps/cast.tsv" ]; then
    echo ""
    echo "=== CHAPTER SUMMARIES ==="
    echo ""
    
    # Display chapter summaries
    if [ -s "EPUB/recaps/recaps.tsv" ]; then
        echo "Chapter | Summary"
        echo "--------|--------"
        cat "EPUB/recaps/recaps.tsv" | head -20
    else
        echo "No chapter summaries found."
    fi
    
    echo ""
    echo "=== CHARACTER PROFILES ==="
    echo ""
    
    # Display character profiles  
    if [ -s "EPUB/recaps/cast.tsv" ]; then
        echo "Character | Role/Description"
        echo "----------|-----------------"
        cat "EPUB/recaps/cast.tsv" | head -20
    else
        echo "No character profiles found."
    fi
    
    echo ""
    echo "=== AI CONFIGURATION ==="
    echo ""
    if [ -f "$HOME/.kobo_recap_ai_config" ]; then
        source "$HOME/.kobo_recap_ai_config"
        echo "Tool: \$AI_TOOL"
        echo "Model: \$AI_MODEL_NAME"
        echo "Endpoint: \$AI_API_ENDPOINT"
    else
        echo "No AI configuration found."
    fi
else
    echo ""
    echo "No recap files found in the book."
    echo "This may be an older version of the book or one processed without AI."
    echo ""
    
    # Show what files are available
    echo "Available files in book:"
    find . -type f | head -10
fi

echo ""
echo "=== PREVIEW COMPLETE ==="
echo ""

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo "Preview complete. The content above shows the AI-generated recap information."
echo "This information will be embedded in your final EPUB file when you process it with:"
echo "./scripts/prepare_book_for_recap_ai.sh \"\$BOOK_FILE\""
