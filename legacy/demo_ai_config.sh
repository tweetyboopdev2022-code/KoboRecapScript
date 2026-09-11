#!/bin/bash

# Demo script to show how the Kobo Recap system handles AI configuration
echo "=== Kobo Recap AI Configuration Demo ==="

# Check if we have cached paths from previous runs
if [ -f "$HOME/.kobo_recap_paths" ]; then
    source "$HOME/.kobo_recap_paths"
    echo "Found existing book paths configuration"
else
    echo "No existing book paths found. Setting up demo..."
    # Create a mock books directory
    mkdir -p "$HOME/kobo_books_demo"
    BOOKS_DIR="$HOME/kobo_books_demo"
    OUTPUT_DIR="$HOME/kobo_output_demo"
    mkdir -p "$OUTPUT_DIR"
    
    # Save for future runs
    echo "BOOKS_DIR=\"$BOOKS_DIR\"" > "$HOME/.kobo_recap_paths"
    echo "OUTPUT_DIR=\"$OUTPUT_DIR\"" >> "$HOME/.kobo_recap_paths"
fi

# Check if we have cached AI configuration
if [ -f "$HOME/.kobo_recap_ai_config" ]; then
    source "$HOME/.kobo_recap_ai_config"
    echo "Found existing AI configuration:"
    echo "  AI Tool: $AI_TOOL"
    echo "  Model: $AI_MODEL_NAME"
    echo "  API Endpoint: $AI_API_ENDPOINT"
else
    echo ""
    echo "=== No AI Configuration Found ==="
    echo "This is the scenario described in the issue."
    echo ""
    echo "The system will automatically prompt for configuration..."
    echo ""
    
    # Simulate what happens when no AI tools are configured
    echo "Simulating AI configuration prompt:"
    echo "1. llama-cli (llama.cpp)"
    echo "2. ollama"
    echo "3. candle (Rust-based LLM)"
    echo "4. Custom API endpoint"
    echo "5. Skip AI processing (use generic recaps)"
    
    # For this demo, we'll choose option 5 (generic recaps)
    echo ""
    echo "Choosing option 5: Skip AI processing (use generic recaps)"
    AI_TOOL="generic"
    AI_MODEL_NAME=""
    AI_API_ENDPOINT=""
    
    # Save configuration
    echo "AI_TOOL=\"$AI_TOOL\"" > "$HOME/.kobo_recap_ai_config"
    echo "AI_MODEL_NAME=\"$AI_MODEL_NAME\"" >> "$HOME/.kobo_recap_ai_config"
    echo "AI_API_ENDPOINT=\"$AI_API_ENDPOINT\"" >> "$HOME/.kobo_recap_ai_config"
    
    echo ""
    echo "Configuration saved!"
    echo "AI_TOOL=$AI_TOOL"
    echo "AI_MODEL_NAME=$AI_MODEL_NAME" 
    echo "AI_API_ENDPOINT=$AI_API_ENDPOINT"
    echo ""
fi

echo "=== Demonstration Complete ==="
echo "The system now has proper AI configuration."
echo "You can proceed with running the main script:"
echo "./prepare_book_for_recap_ai.sh \"Book Title - Author.kepub.epub\""