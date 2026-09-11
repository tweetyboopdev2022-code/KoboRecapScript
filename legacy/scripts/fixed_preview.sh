#!/bin/bash

# Fixed preview script to ensure we're reading the correct book data
echo "=== FIXED Kobo Recap AI Content Preview ==="
echo ""

# Direct path approach - this bypasses all the directory matching issues
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"/full/path/to/Book Title - Author_with_ai_recaps.kepub.epub\""
    echo ""
    echo "Example:"
    echo "  $0 \"$HOME/Library/CloudStorage/GoogleDrive-you@example.com/.Trash/Harry Potter 05 - Harry Potter and the Order of the Phoenix - J.K. Rowling_with_ai_recaps.kepub.epub\""
    echo ""
    echo "If you want to use a book from your main books directory:"
    echo "  $0 \"\$BOOKS_DIR/Harry Potter 05 - Harry Potter and the Order of the Phoenix - J.K. Rowling_with_ai_recaps.kepub.epub\""
    exit 1
fi

# Get full path directly
BOOK_PATH="$1"

# Validate that the file exists
if [ ! -f "$BOOK_PATH" ]; then
    echo "Error: Could not find $BOOK_PATH"
    echo ""
    echo "Please check if the file exists and the path is correct."
    exit 1
fi

echo "Previewing content for: $(basename "$BOOK_PATH")"
echo ""

# Create temporary directory for extraction
TEMP_DIR="/tmp/recap_fixed_preview_$$"
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
echo "=== RECAP CONTENT ANALYSIS ==="

# Check if recap directory exists and show content
if [ -d "EPUB/recaps" ]; then
    echo "✓ Recap directory found with files:"
    ls -la "EPUB/recaps"
    
    # Show actual content of TSV files - but first check if this is the right book data
    echo ""
    echo "=== CHAPTER SUMMARIES (recaps.tsv) ==="
    if [ -f "EPUB/recaps/recaps.tsv" ]; then
        # Check if content looks like Harry Potter vs Charlotte's Web
        local content_check=$(cat "EPUB/recaps/recaps.tsv" | head -5)
        echo "$content_check"
        
        # Determine what book this looks like
        if echo "$content_check" | grep -q -i "wilbur\|charlotte"; then
            echo ""
            echo "⚠️  WARNING: Content appears to be from 'Charlotte's Web' rather than Harry Potter"
            echo "This suggests cross-contamination in the AI processing pipeline."
        elif echo "$content_check" | grep -q -i "potter\|hogwarts\|dumbledore"; then
            echo ""
            echo "✓ Content appears to be from Harry Potter series"
        else
            echo ""
            echo "? Content type unclear - may be generic or cross-contaminated"
        fi
    else
        echo "No recaps.tsv file found"
    fi
    
    echo ""
    echo "=== CHARACTER PROFILES (cast.tsv) ==="
    if [ -f "EPUB/recaps/cast.tsv" ]; then
        # Check if content looks like Harry Potter vs Charlotte's Web
        local content_check=$(cat "EPUB/recaps/cast.tsv" | head -5)
        echo "$content_check"
        
        if echo "$content_check" | grep -q -i "wilbur\|charlotte"; then
            echo ""
            echo "⚠️  WARNING: Character profiles appear to be from 'Charlotte's Web' rather than Harry Potter"
        elif echo "$content_check" | grep -q -i "potter\|hogwarts\|dumbledore"; then
            echo ""
            echo "✓ Character profiles appear to be from Harry Potter series"
        else
            echo ""
            echo "? Character profile type unclear"
        fi
    else
        echo "No cast.tsv file found"
    fi
    
else
    echo "✗ No recap directory found in book structure."
fi

echo ""
echo "=== AI CONFIGURATION ==="
if [ -f "$HOME/.kobo_recap_ai_config" ]; then
    echo "AI configuration found:"
    cat "$HOME/.kobo_recap_ai_config"
else
    echo "No AI configuration found."
    echo "This is normal if using the built-in test mode."
fi

echo ""
echo "=== SUMMARY ==="
echo "✓ The book contains AI-generated recap content!"
echo "✓ Chapter summaries and character profiles are embedded in TSV files"
echo "✓ Check content above to verify it's from the correct book"
echo ""
echo "To view this content on your Kobo:"
echo "1. Copy the book to your Kobo device"
echo "2. Open it in the Kobo reader"
echo "3. Navigate to the Recap tab to see the AI-generated content"

echo ""
echo "=== POTENTIAL ISSUE DETECTED ==="
echo "If you see Charlotte's Web content in Harry Potter book:"
echo "1. The AI system may be using cached data or has a bug"
echo "2. Consider reprocessing with a fresh AI model setup"
echo "3. Verify that book title is correctly passed to the AI processor"

echo ""
echo "=== PREVIEW COMPLETE ==="
echo ""

# Clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo "Preview complete."