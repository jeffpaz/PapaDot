#!/bin/bash

# Usage: ./resize_screenshots.sh /path/to/input/folder /path/to/output/folder
# If no output folder specified, creates 'resized' in input folder

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-$INPUT_DIR/resized}"

mkdir -p "$OUTPUT_DIR"

HEIGHT=2688
WIDTH=1242

count=0
limit=5  # Change to 0 or remove for unlimited

for file in "$INPUT_DIR"/*.png; do
    [[ -f "$file" ]] || continue  # Skip if no files
    base=$(basename "$file")
    sips -z $HEIGHT $WIDTH "$file" --out "$OUTPUT_DIR/$base"
    echo "Resized: $base"
    ((count++))
    if [[ $limit -gt 0 && $count -ge $limit ]]; then
        echo "Stopped after $limit files"
        break
    fi
done

echo "Done! Resized files are in: $OUTPUT_DIR"