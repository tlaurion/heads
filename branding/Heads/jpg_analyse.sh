#!/bin/bash

# Directory containing the images
DIR="."

# Function to get color depth
get_color_depth() {
    identify -format "%z" "$1"
}

# Function to get unique colors
get_unique_colors() {
    identify -format "%k" "$1"
}

# Function to get compression type
get_compression_type() {
    identify -format "%C" "$1"
}

# Loop through all jpg files in the directory
for image in $DIR/*.jpg; do
    echo "Analyzing: $image"
    
    # Get image dimensions and size
    dimensions=$(identify -format "%wx%h" "$image")
    size=$(wc -c < "$image")
    
    # Get color information
    colorspace=$(identify -format "%r" "$image")
    color_depth=$(get_color_depth "$image")
    unique_colors=$(get_unique_colors "$image")
    
    # Get compression information
    compression=$(get_compression_type "$image")
    quality=$(identify -format "%Q" "$image")
    
    # Get additional metadata
    has_profile=$(identify -format "%[profile:icc]" "$image")
    [ -z "$has_profile" ] && has_profile="No" || has_profile="Yes"
    
    has_exif=$(identify -format "%[EXIF:*]" "$image")
    [ -z "$has_exif" ] && has_exif="No" || has_exif="Yes"
    
    echo "Dimensions: $dimensions"
    echo "File size: $size bytes"
    echo "Colorspace: $colorspace"
    echo "Color depth: $color_depth-bit"
    echo "Unique colors: $unique_colors"
    echo "Compression: $compression"
    echo "Quality: $quality"
    echo "Has ICC Profile: $has_profile"
    echo "Has EXIF data: $has_exif"
    echo "----------------------------"
done
