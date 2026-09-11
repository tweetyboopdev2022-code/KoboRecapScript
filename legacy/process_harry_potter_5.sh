#!/bin/bash

# Process Harry Potter 5 book using the Kobo Recap System
echo "=== Processing Harry Potter 5 Book ==="

# Set the path to your Harry Potter 5 book
BOOK_PATH="$HOME/kobo-backups/FULL-20260828-145749/books/Harry Potter 05 - Harry Potter and the Order of the Phoenix - J.K. Rowling.kepub.epub"

# Check if the book exists
if [ ! -f "$BOOK_PATH" ]; then
    echo "Error: Book not found at $BOOK_PATH"
    exit 1
fi

echo "Found book: $(basename "$BOOK_PATH")"
echo "Processing with Kobo Recap System..."

# Run the main processing script with the Harry Potter 5 book as argument
cd $HOME/sites/mods/kobo-recap-system
./prepare_book_for_recap_ai.sh "$BOOK_PATH"

echo "=== Processing Complete ==="
echo "Check the output files in the current directory."