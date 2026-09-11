#!/bin/bash

# AI Configuration Prompt Script for Kobo Recap System
# This script prompts users for their AI tool preferences and sets up the environment

echo "=== AI Configuration for Kobo Recap System ==="
echo ""

# Check if we already have cached AI configuration
if [ -f "$HOME/.kobo_recap_ai_config" ]; then
    echo "Found existing AI configuration. Loading..."
    source "$HOME/.kobo_recap_ai_config"
    echo "Current configuration:"
    echo "  AI Tool: $AI_TOOL"
    echo "  Model: $AI_MODEL_NAME"
    echo "  API Endpoint: $AI_API_ENDPOINT"
    echo ""
fi

# Prompt for AI tool selection
echo "Please select your preferred local AI tool for book analysis:"
echo "1. llama-cli (llama.cpp)"
echo "2. ollama"
echo "3. candle (Rust-based LLM)"
echo "4. Custom API endpoint"
echo "5. Skip AI processing (use generic recaps)"

read -p "Enter your choice (1-5): " ai_choice

case $ai_choice in
    1)
        if command -v llama-cli &> /dev/null; then
            echo "llama-cli detected."
            AI_TOOL="llama-cli"
            AI_MODEL_NAME="llama2-7b"
            AI_API_ENDPOINT=""
            echo "Using: $AI_TOOL with model $AI_MODEL_NAME"
        else
            echo "Warning: llama-cli not found. Please install it first."
            echo "Proceeding with generic recaps..."
            AI_TOOL="generic"
            AI_MODEL_NAME=""
            AI_API_ENDPOINT=""
        fi
        ;;
    2)
        if command -v ollama &> /dev/null; then
            echo "ollama detected."
            AI_TOOL="ollama"
            read -p "Enter model name (default: llama3): " model_input
            AI_MODEL_NAME="${model_input:-llama3}"
            AI_API_ENDPOINT=""
            echo "Using: $AI_TOOL with model $AI_MODEL_NAME"
        else
            echo "Warning: ollama not found. Please install it first."
            echo "Proceeding with generic recaps..."
            AI_TOOL="generic"
            AI_MODEL_NAME=""
            AI_API_ENDPOINT=""
        fi
        ;;
    3)
        if command -v candle &> /dev/null; then
            echo "candle detected."
            AI_TOOL="candle"
            read -p "Enter model name (default: llama2-7b): " model_input
            AI_MODEL_NAME="${model_input:-llama2-7b}"
            AI_API_ENDPOINT=""
            echo "Using: $AI_TOOL with model $AI_MODEL_NAME"
        else
            echo "Warning: candle not found. Please install it first."
            echo "Proceeding with generic recaps..."
            AI_TOOL="generic"
            AI_MODEL_NAME=""
            AI_API_ENDPOINT=""
        fi
        ;;
    4)
        echo "Custom API endpoint configuration:"
        read -p "Enter API endpoint URL (e.g., http://localhost:11434/api/generate): " api_endpoint
        read -p "Enter model name (e.g., llama3): " model_name
        AI_TOOL="custom"
        AI_MODEL_NAME="$model_name"
        AI_API_ENDPOINT="$api_endpoint"
        echo "Using custom API endpoint: $AI_API_ENDPOINT with model $AI_MODEL_NAME"
        ;;
    5)
        echo "Skipping AI processing. Using generic recaps only."
        AI_TOOL="generic"
        AI_MODEL_NAME=""
        AI_API_ENDPOINT=""
        ;;
    *)
        echo "Invalid choice. Using generic recaps as fallback."
        AI_TOOL="generic"
        AI_MODEL_NAME=""
        AI_API_ENDPOINT=""
        ;;
esac

# Save configuration for future use
echo "AI_TOOL=\"$AI_TOOL\"" > "$HOME/.kobo_recap_ai_config"
echo "AI_MODEL_NAME=\"$AI_MODEL_NAME\"" >> "$HOME/.kobo_recap_ai_config"
echo "AI_API_ENDPOINT=\"$AI_API_ENDPOINT\"" >> "$HOME/.kobo_recap_ai_config"

echo ""
echo "=== Configuration Saved ==="
echo "To change this configuration later, delete $HOME/.kobo_recap_ai_config"
echo ""
echo "Next steps:"
echo "1. Install your chosen AI tool if not already installed"
echo "2. Run the main script: ./prepare_book_for_recap_ai.sh \"Book Title - Author.kepub.epub\""
echo ""

exit 0