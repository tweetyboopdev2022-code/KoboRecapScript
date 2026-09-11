#!/bin/bash

# AI Configuration Setup Script for Kobo Recap System
# This script demonstrates how to properly configure the system with AI tools

echo "=== Setting Up AI Configuration for Harry Potter 5 ==="

# Check if we have cached paths from previous runs
if [ -f "$HOME/.kobo_recap_paths" ]; then
    source "$HOME/.kobo_recap_paths"
fi

# Check if we have cached AI configuration
if [ -f "$HOME/.kobo_recap_ai_config" ]; then
    echo "Existing AI configuration found:"
    cat "$HOME/.kobo_recap_ai_config"
    echo ""
else
    echo "No existing AI configuration found. Setting up new configuration..."
fi

# Set up configuration for Harry Potter 5 book processing
echo "Setting up configuration for AI-powered recap generation..."

# Create a temporary config file with the right settings
cat > "$HOME/.kobo_recap_ai_config" << EOF
# AI Configuration for Kobo Recap System
# MODEL CHOICE - measured on this setup 10 Sep 2026, do not change casually.
#
# Use a general model, NOT a coder model. Recap generation is prose
# summarisation. qwen3-coder produced generic boilerplate here ("Chapter 10:
# Final chapters that conclude the main plot") while llama3.1 produced
# accurate, book-specific summaries from exactly the same chapters.
#
# It must also fit the RTX 3070 8 GB entirely, or throughput falls off a cliff:
#   llama3.1 (8B q4)     5.9 GB resident @ 16k ctx   100% GPU   6-13 s/chapter
#   qwen3-coder:30b-a3b  20  GB resident @ 32k ctx    31% GPU   ~158 s/chapter
#
# The a3b means Mixture-of-Experts with ~3B active parameters per token. That
# reduces compute, NOT memory: every expert stays resident, so the model
# offloads to CPU and each token crosses PCIe.
#
# Roughly 7-8B at 4-bit fits. 14B at 4-bit is ~9 GB and already spills.
# Keep num_ctx at 16384; a large KV cache can push even a 7B model over.
#
# Also: only one model fits at a time. If the dsh harness is running against
# this same Ollama with a different model, the two evict each other on every
# call and both crawl. Stop the harness before a batch run.
#
# llama3:8b-instruct-q4_K_M was the previous default but is not installed on
# the nobara host. llama3.1:latest is, and is the one that was verified.
AI_TOOL="ollama"
AI_MODEL_NAME="llama3.1:latest"
AI_API_ENDPOINT="http://localhost:11434"
EOF

echo "Configuration saved to $HOME/.kobo_recap_ai_config"
echo ""
echo "Configuration details:"
cat "$HOME/.kobo_recap_ai_config"

# Set the BOOKS_DIR for Harry Potter books
if [ -z "$BOOKS_DIR" ]; then
    echo ""
    echo "Setting up book paths..."
    BOOKS_DIR="$HOME/kobo-backups/FULL-20260828-145749/books"
    
    # Validate the directory exists
    if [ ! -d "$BOOKS_DIR" ]; then
        echo "Error: Directory '$BOOKS_DIR' does not exist."
        exit 1
    fi
    
    # Save for future runs
    echo "BOOKS_DIR=\"$BOOKS_DIR\"" > "$HOME/.kobo_recap_paths"
    echo "Output directory path (will be set later):"
    read -p "Please specify the output directory for recap-enabled books: " OUTPUT_DIR
    echo "OUTPUT_DIR=\"$OUTPUT_DIR\"" >> "$HOME/.kobo_recap_paths"
fi

echo ""
echo "=== Configuration Complete ==="
echo "You can now process your Harry Potter 5 book with:"
echo "./prepare_book_for_recap_ai.sh \"Harry Potter 05 - Harry Potter and the Order of the Phoenix - J.K. Rowling.kepub.epub\""

# Verify the book exists
BOOK_PATH="$BOOKS_DIR/Harry Potter 05 - Harry Potter and the Order of the Phoenix - J.K. Rowling.kepub.epub"
if [ -f "$BOOK_PATH" ]; then
    echo ""
    echo "Found your Harry Potter 5 book: $(basename "$BOOK_PATH")"
else
    echo ""
    echo "Warning: Could not find Harry Potter 5 book in expected location"
    echo "Expected path: $BOOK_PATH"
fi

echo ""
echo "Note: This configuration uses Ollama with the Llama3 model."
echo "The AI will process your book content and generate story-specific recaps."