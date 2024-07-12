#!/bin/bash

# Directory containing the images
DIR="."

# Target file size in bytes (15KB)
TARGET_SIZE=15360

# Loop through all jpg files in the directory
for image in $DIR/*.jpg; do
    # Get original image dimensions and size
    original_dimensions=$(identify -format "%wx%h" "$image")
    original_size=$(wc -c < "$image")
    
    echo "Processing: $image"
    echo "Original dimensions: $original_dimensions, Size: $original_size bytes"
    
    # Optimize the image in place
    convert "$image" -colorspace Gray -define jpeg:extent=${TARGET_SIZE}b "$image"
    
    # Get new file info
    new_dimensions=$(identify -format "%wx%h" "$image")
    new_size=$(wc -c < "$image")
    
    echo "Optimized: $image"
    echo "New dimensions: $new_dimensions, Size: $new_size bytes"
    echo "----------------------------"
done
