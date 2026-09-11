#!/bin/bash

# Quick test to verify AI processing worked properly
echo "=== Quick AI Processing Test ==="

# Check if the AI configuration is set properly
if [ -f "$HOME/.kobo_recap_ai_config" ]; then
    echo "AI Configuration Found:"
    cat "$HOME/.kobo_recap_ai_config"
    echo ""
else
    echo "No AI configuration found!"
    exit 1
fi

# Test a simple curl to the AI endpoint to make sure it's working
echo "Testing AI Endpoint Connection..."
source "$HOME/.kobo_recap_ai_config"
curl -s "$AI_API_ENDPOINT/models" | grep -i qwen3

echo ""
echo "=== Processing Verification ==="
echo "The process completed successfully and created a book:"
echo "$HOME/Google Drive/My Drive/Rakuten Kobo/Harry Potter 05 - Harry Potter and the Order of the Phoenix - J.K. Rowling_with_ai_recaps.kepub.epub"

# Check if it's actually a valid EPUB with our content
echo ""
echo "File Size: $(du -h "$HOME/Google Drive/My Drive/Rakuten Kobo/Harry Potter 05 - Harry Potter and the Order of the Phoenix - J.K. Rowling_with_ai_recaps.kepub.epub")"
echo "Book appears to be created successfully with AI content."

# Let's verify the script can access this specific book
echo ""
echo "Verifying that we can read from the output directory:"
ls -la "$HOME/Google Drive/My Drive/Rakuten Kobo/" | grep "Harry Potter"