#!/bin/bash

# Demo script to show how AI integration works with different book examples

echo "=== Kobo Recap AI Integration Demo ==="
echo ""

# Show current configuration if exists
if [ -f "$HOME/.kobo_recap_ai_config" ]; then
    echo "Current AI Configuration:"
    source "$HOME/.kobo_recap_ai_config"
    echo "  Tool: $AI_TOOL"
    echo "  Model: $AI_MODEL_NAME"
    echo ""
else
    echo "No AI configuration found. Running configuration prompt..."
    echo ""
    ./scripts/ai_config_prompt.sh
    exit 0
fi

echo "Demo Features:"
echo "1. Dynamic AI tool detection and selection"
echo "2. Story-specific recap generation" 
echo "3. Multi-tool support (llama-cli, ollama, candle)"
echo "4. Configuration persistence"
echo ""

# Show book processing example for Harry Potter (simulated)
echo "Example Book Processing:"
echo "Book: Harry Potter and the Philosopher's Stone - J.K. Rowling.kepub.epub"
echo ""
echo "AI would analyze this specific content to generate:"
echo "- Chapter summaries aligned with actual plot progression"  
echo "- Character profiles based on real character development"
echo "- Thematic analysis matching the story's actual themes"
echo ""

# Show what happens when no AI is configured
if [ "$AI_TOOL" = "generic" ]; then
    echo ""
    echo "Warning: No AI tools configured."
    echo "The system will use generic recap content instead of story-specific analysis."
    echo "To enable AI features, run:"
    echo "./scripts/ai_config_prompt.sh"
fi

echo ""
echo "=== Demo Complete ==="
echo "To process actual books with AI integration:"
echo "./scripts/prepare_book_for_recap_ai.sh \"Book Title - Author.kepub.epub\""

exit 0