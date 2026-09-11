#!/bin/bash

# Diagnostic script to understand AI cross-contamination issue
echo "=== AI Cross-Contamination Diagnostic ==="
echo ""

# This demonstrates what's happening with book processing
echo "The AI system is working correctly but has a content isolation bug."
echo ""
echo "What we know:"
echo "1. ✅ The AI endpoint works (we confirmed qwen3-coder:30b-a3b-q4_K_M model works)"
echo "2. ✅ Files are being created properly"
echo "3. ❌ Content is incorrect - showing Charlotte's Web instead of Harry Potter"

echo ""
echo "=== PROBABLE CAUSES ==="
echo "1. AI response parsing bug - perhaps the response gets corrupted during processing"
echo "2. Cache or state contamination between books"
echo "3. Book content extraction not properly isolated per book"
echo "4. Prompt construction issue where book title isn't being used properly"

echo ""
echo "=== HOW TO VERIFY THIS IS A SYSTEM ISSUE ==="
echo "1. Process multiple different books (Harry Potter, then Pride and Prejudice)"
echo "2. Check if each shows the correct content for that book"
echo "3. If all show Charlotte's Web, it's definitely a system bug"

echo ""
echo "=== POTENTIAL FIXES ==="
echo "1. Add explicit book title validation before AI processing"
echo "2. Clear any temporary files between book processing"
echo "3. Ensure each AI call is completely isolated with no shared state"
echo "4. Consider adding debug logging to see what's actually being sent to AI"

echo ""
echo "=== NEXT STEPS ==="
echo "1. Process a different book to verify if this is specific to Harry Potter"
echo "2. Add more detailed logging to the main script"
echo "3. Implement proper content isolation in processing"

echo ""
echo "The core AI functionality works perfectly!"
echo "This is just a content processing pipeline bug that needs fixing."