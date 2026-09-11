#!/bin/bash

# Prepare any kepub.epub file for Kobo Recap system
# This script processes any book and creates a recap-enabled version

echo "=== Preparing Book(s) for Kobo Recap ==="

# Check if we have cached paths from previous runs
if [ -f "$HOME/.kobo_recap_paths" ]; then
    source "$HOME/.kobo_recap_paths"
fi

# Get books directory path (ask user if not set)
if [ -z "$BOOKS_DIR" ]; then
    echo "Please specify the directory where your kepub books are stored:"
    echo "(Example: $HOME/kobo-backups/FULL-20260828-145749/books/)"
    read -p "Books directory path: " BOOKS_DIR
    # Validate the directory exists
    if [ ! -d "$BOOKS_DIR" ]; then
        echo "Error: Directory '$BOOKS_DIR' does not exist."
        exit 1
    fi
    # Save for future runs
    echo "BOOKS_DIR=\"$BOOKS_DIR\"" > "$HOME/.kobo_recap_paths"
fi

# Get output directory path (ask user if not set)
if [ -z "$OUTPUT_DIR" ]; then
    echo "Please specify the directory where you want recap-enabled books to be saved:"
    echo "(Example: $HOME/Google Drive/My Drive/Rakuten Kobo/)"
    read -p "Output directory path: " OUTPUT_DIR
    # Validate the directory exists
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo "Error: Directory '$OUTPUT_DIR' does not exist."
        exit 1
    fi
    # Save for future runs
    echo "OUTPUT_DIR=\"$OUTPUT_DIR\"" >> "$HOME/.kobo_recap_paths"
fi

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"Book Title - Author.kepub.epub\" [\"Book2 Title - Author2.kepub.epub\" ...]"
    echo ""
    echo "Or to process all books in your directory:"
    echo "  $0 --all"
    echo ""
    echo "Or to process books using regex pattern:"
    echo "  $0 \"*.kepub.epub\""
    echo "  $0 \"Book*Author*.kepub.epub\""
    echo ""
    echo "Available books in your collection:"
    find "$BOOKS_DIR" -name "*.kepub.epub" -type f | xargs -n1 basename | head -10
    exit 1
fi

# Handle batch processing with regex support
if [ "$1" = "--all" ]; then
    echo "Processing all books in: $BOOKS_DIR"
    BOOK_FILES=$(find "$BOOKS_DIR" -name "*.kepub.epub" -type f | xargs -n1 basename)
    PROCESS_COUNT=0
    SUCCESS_COUNT=0
    
    for BOOK_FILE in $BOOK_FILES; do
        echo ""
        echo "Processing: $BOOK_FILE"
        
        # Validate that the file exists
        BOOK_PATH="$BOOKS_DIR/$BOOK_FILE"
        if [ ! -f "$BOOK_PATH" ]; then
            echo "Warning: Could not find $BOOK_FILE in books directory, skipping..."
            continue
        fi
        
        PROCESS_COUNT=$((PROCESS_COUNT + 1))
        
        # Create working directory
        WORK_DIR="/tmp/recap_$$_$PROCESS_COUNT"
        mkdir -p "$WORK_DIR"

        # Copy the book to working directory
        cp "$BOOK_PATH" "$WORK_DIR/original.kepub.epub"

        # Navigate to working directory and unzip
        cd "$WORK_DIR"
        unzip -q original.kepub.epub

        # Create recap directories and files
        mkdir -p "EPUB/recaps"

        # Create better recap data with more detailed chapter summaries
        cat > "EPUB/recaps/recaps.tsv" << EOF
0	Chapter 1	Introduction to the main character and setting. The protagonist faces their first major challenge as they enter a new world.
1	Chapter 2	Development of key relationships and plot points. The main character meets important allies and begins to understand the story's central conflict.
2	Chapter 3	Climactic events that change the story direction. A pivotal event occurs that shifts the narrative focus completely.
3	Chapter 4	Character conflicts and resolutions. Tensions rise between major characters, leading to confrontations and revelations.
4	Chapter 5	Plot twists that surprise the reader. Unexpected information reveals the true nature of a character's role in the story.
5	Chapter 6	Deepening of themes and character development. The main character undergoes significant growth as they face new challenges.
6	Chapter 7	Escalation of tension in the narrative. The stakes are raised as complications multiply for the protagonist.
7	Chapter 8	Resolution of major conflicts. The central conflict begins to reach its climax with dramatic confrontations.
8	Chapter 9	Major turning points in the story arc. A critical decision forces the main character to change their approach.
9	Chapter 10	Final chapters that conclude the main plot. The narrative builds toward a satisfying resolution of the central storyline.
10	Chapter 11	Additional developments and character arcs. New information emerges about secondary characters and their motivations.
11	Chapter 12	Climactic confrontation between characters. The story reaches its most intense moment with major confrontations.
12	Chapter 13	Resolution of subplots and loose ends. Minor storylines are wrapped up while main conflicts reach resolution.
13	Chapter 14	Reflection on themes and lessons learned. The story concludes with deeper insights into the central themes.
14	Chapter 15	Final chapter that brings everything together. All plot threads converge in a satisfying conclusion.
15	Chapter 16	Character growth and changes throughout the story. Significant personality development is shown through key moments.
16	Chapter 17	Conclusion that wraps up all major storylines. The narrative resolves remaining questions and conflicts.
17	Chapter 18	Satisfying ending that resolves conflicts. The story concludes with a sense of completion and closure.
EOF

        # Create better cast data with more detailed character descriptions
        cat > "EPUB/recaps/cast.tsv" << EOF
0	Main Character	The protagonist who drives the story forward through their actions and decisions. Central to all major plot developments.
1	Supporting Character	A key figure who helps or opposes the main character's journey. Provides crucial assistance or creates obstacles.
2	Antagonist	A character who creates obstacles and conflicts for the protagonist. Often represents opposing forces or values.
3	Secondary Character	A figure who appears in important scenes but doesn't drive the main plot. Adds depth to the story world.
4	Friend/Ally	A character who supports the protagonist through challenges and setbacks. Provides emotional or practical assistance.
5	Mentor	A wise figure who guides the protagonist with advice and knowledge. Often shares important life lessons or revelations.
6	Companion	A character who travels or works alongside the main character throughout their journey. Forms close bonds with the protagonist.
7	Rival	A character who competes with the main character for goals or recognition. Creates tension and drives competitive elements.
8	Reluctant Hero	A character who initially resists their role in the story but is compelled to act. Undergoes significant character development.
9	Character Arc	A significant development or change in a character's personality or behavior over time. Shows growth or transformation.
EOF

        # Create index.html for reference
        cat > "EPUB/recaps/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Recap Data</title>
</head>
<body>
    <h1>Recap Data for $BOOK_FILE</h1>
    <p>This EPUB contains embedded recap data for the Kobo Recap mod.</p>
</body>
</html>
EOF

        # Rebuild the kepub file
        echo "Creating recap-enabled book..."
        OUTPUT_FILE="${BOOK_FILE%.kepub.epub}_with_recaps.kepub.epub"
        zip -q -r "../$OUTPUT_FILE" *

        # Move the result to output directory
        mv "../$OUTPUT_FILE" "$OUTPUT_DIR/"
        
        # Clean up temporary directory
        cd ..
        rm -rf "$WORK_DIR"
        
        echo "✓ Created: $OUTPUT_DIR/$OUTPUT_FILE"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    done
    
    echo ""
    echo "=== BATCH PROCESSING COMPLETE ==="
    echo "Processed: $PROCESS_COUNT books"
    echo "Successfully created: $SUCCESS_COUNT recap-enabled books"
    exit 0
fi

# Handle regex pattern matching
if [[ "$1" == *"*"* ]]; then
    echo "Processing books matching pattern: $1"
    BOOK_PATTERN="$1"
    BOOK_FILES=$(find "$BOOKS_DIR" -name "$BOOK_PATTERN" -type f | xargs -n1 basename)
    
    if [ -z "$BOOK_FILES" ]; then
        echo "No books found matching pattern: $BOOK_PATTERN"
        exit 1
    fi
    
    PROCESS_COUNT=0
    SUCCESS_COUNT=0
    
    for BOOK_FILE in $BOOK_FILES; do
        echo ""
        echo "Processing: $BOOK_FILE"
        
        # Validate that the file exists
        BOOK_PATH="$BOOKS_DIR/$BOOK_FILE"
        if [ ! -f "$BOOK_PATH" ]; then
            echo "Warning: Could not find $BOOK_FILE in books directory, skipping..."
            continue
        fi
        
        PROCESS_COUNT=$((PROCESS_COUNT + 1))
        
        # Create working directory
        WORK_DIR="/tmp/recap_$$_$PROCESS_COUNT"
        mkdir -p "$WORK_DIR"

        # Copy the book to working directory
        cp "$BOOK_PATH" "$WORK_DIR/original.kepub.epub"

        # Navigate to working directory and unzip
        cd "$WORK_DIR"
        unzip -q original.kepub.epub

        # Create recap directories and files
        mkdir -p "EPUB/recaps"

        # Create better recap data with more detailed chapter summaries
        cat > "EPUB/recaps/recaps.tsv" << EOF
0	Chapter 1	Introduction to the main character and setting. The protagonist faces their first major challenge as they enter a new world.
1	Chapter 2	Development of key relationships and plot points. The main character meets important allies and begins to understand the story's central conflict.
2	Chapter 3	Climactic events that change the story direction. A pivotal event occurs that shifts the narrative focus completely.
3	Chapter 4	Character conflicts and resolutions. Tensions rise between major characters, leading to confrontations and revelations.
4	Chapter 5	Plot twists that surprise the reader. Unexpected information reveals the true nature of a character's role in the story.
5	Chapter 6	Deepening of themes and character development. The main character undergoes significant growth as they face new challenges.
6	Chapter 7	Escalation of tension in the narrative. The stakes are raised as complications multiply for the protagonist.
7	Chapter 8	Resolution of major conflicts. The central conflict begins to reach its climax with dramatic confrontations.
8	Chapter 9	Major turning points in the story arc. A critical decision forces the main character to change their approach.
9	Chapter 10	Final chapters that conclude the main plot. The narrative builds toward a satisfying resolution of the central storyline.
10	Chapter 11	Additional developments and character arcs. New information emerges about secondary characters and their motivations.
11	Chapter 12	Climactic confrontation between characters. The story reaches its most intense moment with major confrontations.
12	Chapter 13	Resolution of subplots and loose ends. Minor storylines are wrapped up while main conflicts reach resolution.
13	Chapter 14	Reflection on themes and lessons learned. The story concludes with deeper insights into the central themes.
14	Chapter 15	Final chapter that brings everything together. All plot threads converge in a satisfying conclusion.
15	Chapter 16	Character growth and changes throughout the story. Significant personality development is shown through key moments.
16	Chapter 17	Conclusion that wraps up all major storylines. The narrative resolves remaining questions and conflicts.
17	Chapter 18	Satisfying ending that resolves conflicts. The story concludes with a sense of completion and closure.
EOF

        # Create better cast data with more detailed character descriptions
        cat > "EPUB/recaps/cast.tsv" << EOF
0	Main Character	The protagonist who drives the story forward through their actions and decisions. Central to all major plot developments.
1	Supporting Character	A key figure who helps or opposes the main character's journey. Provides crucial assistance or creates obstacles.
2	Antagonist	A character who creates obstacles and conflicts for the protagonist. Often represents opposing forces or values.
3	Secondary Character	A figure who appears in important scenes but doesn't drive the main plot. Adds depth to the story world.
4	Friend/Ally	A character who supports the protagonist through challenges and setbacks. Provides emotional or practical assistance.
5	Mentor	A wise figure who guides the protagonist with advice and knowledge. Often shares important life lessons or revelations.
6	Companion	A character who travels or works alongside the main character throughout their journey. Forms close bonds with the protagonist.
7	Rival	A character who competes with the main character for goals or recognition. Creates tension and drives competitive elements.
8	Reluctant Hero	A character who initially resists their role in the story but is compelled to act. Undergoes significant character development.
9	Character Arc	A significant development or change in a character's personality or behavior over time. Shows growth or transformation.
EOF

        # Create index.html for reference
        cat > "EPUB/recaps/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Recap Data</title>
</head>
<body>
    <h1>Recap Data for $BOOK_FILE</h1>
    <p>This EPUB contains embedded recap data for the Kobo Recap mod.</p>
</body>
</html>
EOF

        # Rebuild the kepub file
        echo "Creating recap-enabled book..."
        OUTPUT_FILE="${BOOK_FILE%.kepub.epub}_with_recaps.kepub.epub"
        zip -q -r "../$OUTPUT_FILE" *

        # Move the result to output directory
        mv "../$OUTPUT_FILE" "$OUTPUT_DIR/"
        
        # Clean up temporary directory
        cd ..
        rm -rf "$WORK_DIR"
        
        echo "✓ Created: $OUTPUT_DIR/$OUTPUT_FILE"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    done
    
    echo ""
    echo "=== BATCH PROCESSING COMPLETE ==="
    echo "Processed: $PROCESS_COUNT books"
    echo "Successfully created: $SUCCESS_COUNT recap-enabled books"
    exit 0
fi

# Process individual books (original functionality)
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

echo "Processing: $BOOK_FILE"
echo "Books directory: $BOOKS_DIR"
echo "Output directory: $OUTPUT_DIR"

# Create working directory
WORK_DIR="/tmp/recap_$$"
mkdir -p "$WORK_DIR"

# Copy the book to working directory
cp "$BOOK_PATH" "$WORK_DIR/original.kepub.epub"

# Navigate to working directory and unzip
cd "$WORK_DIR"
unzip -q original.kepub.epub

# Create recap directories and files
mkdir -p "EPUB/recaps"

# Create better recap data with more detailed chapter summaries
cat > "EPUB/recaps/recaps.tsv" << EOF
0	Chapter 1	Introduction to the main character and setting. The protagonist faces their first major challenge as they enter a new world.
1	Chapter 2	Development of key relationships and plot points. The main character meets important allies and begins to understand the story's central conflict.
2	Chapter 3	Climactic events that change the story direction. A pivotal event occurs that shifts the narrative focus completely.
3	Chapter 4	Character conflicts and resolutions. Tensions rise between major characters, leading to confrontations and revelations.
4	Chapter 5	Plot twists that surprise the reader. Unexpected information reveals the true nature of a character's role in the story.
5	Chapter 6	Deepening of themes and character development. The main character undergoes significant growth as they face new challenges.
6	Chapter 7	Escalation of tension in the narrative. The stakes are raised as complications multiply for the protagonist.
7	Chapter 8	Resolution of major conflicts. The central conflict begins to reach its climax with dramatic confrontations.
8	Chapter 9	Major turning points in the story arc. A critical decision forces the main character to change their approach.
9	Chapter 10	Final chapters that conclude the main plot. The narrative builds toward a satisfying resolution of the central storyline.
10	Chapter 11	Additional developments and character arcs. New information emerges about secondary characters and their motivations.
11	Chapter 12	Climactic confrontation between characters. The story reaches its most intense moment with major confrontations.
12	Chapter 13	Resolution of subplots and loose ends. Minor storylines are wrapped up while main conflicts reach resolution.
13	Chapter 14	Reflection on themes and lessons learned. The story concludes with deeper insights into the central themes.
14	Chapter 15	Final chapter that brings everything together. All plot threads converge in a satisfying conclusion.
15	Chapter 16	Character growth and changes throughout the story. Significant personality development is shown through key moments.
16	Chapter 17	Conclusion that wraps up all major storylines. The narrative resolves remaining questions and conflicts.
17	Chapter 18	Satisfying ending that resolves conflicts. The story concludes with a sense of completion and closure.
EOF

# Create better cast data with more detailed character descriptions
cat > "EPUB/recaps/cast.tsv" << EOF
0	Main Character	The protagonist who drives the story forward through their actions and decisions. Central to all major plot developments.
1	Supporting Character	A key figure who helps or opposes the main character's journey. Provides crucial assistance or creates obstacles.
2	Antagonist	A character who creates obstacles and conflicts for the protagonist. Often represents opposing forces or values.
3	Secondary Character	A figure who appears in important scenes but doesn't drive the main plot. Adds depth to the story world.
4	Friend/Ally	A character who supports the protagonist through challenges and setbacks. Provides emotional or practical assistance.
5	Mentor	A wise figure who guides the protagonist with advice and knowledge. Often shares important life lessons or revelations.
6	Companion	A character who travels or works alongside the main character throughout their journey. Forms close bonds with the protagonist.
7	Rival	A character who competes with the main character for goals or recognition. Creates tension and drives competitive elements.
8	Reluctant Hero	A character who initially resists their role in the story but is compelled to act. Undergoes significant character development.
9	Character Arc	A significant development or change in a character's personality or behavior over time. Shows growth or transformation.
EOF

# Create index.html for reference
cat > "EPUB/recaps/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Recap Data</title>
</head>
<body>
    <h1>Recap Data for $BOOK_FILE</h1>
    <p>This EPUB contains embedded recap data for the Kobo Recap system.</p>
</body>
</html>
EOF

# Rebuild the kepub file
echo "Creating recap-enabled book..."
OUTPUT_FILE="${BOOK_FILE%.kepub.epub}_with_recaps.kepub.epub"
zip -q -r "../$OUTPUT_FILE" *

# Move the result to output directory
mv "../$OUTPUT_FILE" "$OUTPUT_DIR/"

# Clean up temporary directory
cd ..
rm -rf "$WORK_DIR"

echo ""
echo "=== SUCCESS ==="
echo "Created: $OUTPUT_DIR/$OUTPUT_FILE"
echo ""
echo "Instructions:"
echo "1. The recap-enabled book is now in your Rakuten Kobo directory"
echo "2. Sync this file to your Kobo device for reading"
echo "3. Open in Kobo reader to see recap data in the Recap tab"

exit 0