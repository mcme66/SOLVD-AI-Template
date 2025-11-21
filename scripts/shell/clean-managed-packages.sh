#!/bin/bash

###############################################################################
# Clean Managed Packages Script
#
# Purpose: Removes hidden managed package content from LWC and Aura directories
#
# This script identifies and removes components where ALL files contain only
# placeholder content (hidden;, (hidden), or hidden). Components with mixed
# content (some hidden, some real) are preserved.
#
# Bash 3.x Compatible: Works on macOS default bash 3.2.x
# Note: Uses traditional loops instead of process substitution to avoid
#       bus errors on bash 3.2
#
# Usage: ./clean-managed-packages.sh [-d <metadata-dir>] [--dry-run] [-h]
###############################################################################

set -e

# Default values
METADATA_DIR="force-app"
DRY_RUN=false

# Statistics
lwc_removed_count=0
aura_removed_count=0
lwc_removed_files=0
aura_removed_files=0
lwc_skipped_count=0
aura_skipped_count=0

# Temp files for storing removed component names (bash 3.x compatible)
TEMP_LWC_NAMES=""
TEMP_AURA_NAMES=""

print_usage() {
    echo "Usage: $0 [-d <metadata-dir>] [--dry-run] [-h|--help]"
    echo
    echo "Removes hidden managed package content from LWC and Aura directories."
    echo
    echo "Options:"
    echo "   -d <dir>     Metadata directory (default: force-app)"
    echo "   --dry-run    Preview what would be removed without deleting"
    echo "   -h, --help   Show this help message"
    echo
    echo "Examples:"
    echo "   $0                           # Clean with defaults"
    echo "   $0 --dry-run                 # Preview without removing"
    echo "   $0 -d ./my-metadata          # Use custom directory"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d)
            METADATA_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Create temp files for storing component names
TEMP_LWC_NAMES=$(mktemp)
TEMP_AURA_NAMES=$(mktemp)

# Cleanup temp files on exit
cleanup() {
    rm -f "$TEMP_LWC_NAMES" "$TEMP_AURA_NAMES"
}
trap cleanup EXIT

# Function to check if a file is hidden managed package content
is_hidden_file() {
    local file="$1"

    # Check if file exists and is a regular file
    if [[ ! -f "$file" ]]; then
        return 1  # Not hidden
    fi

    # Check file size (must be <= 10 bytes)
    # Note: tr -d ' ' ensures bash 3.x compatibility by trimming whitespace from wc output
    local file_size=$(wc -c < "$file" | tr -d ' ')
    file_size=${file_size:-999}
    if [[ $file_size -gt 10 ]]; then
        return 1  # Not hidden
    fi

    # Read and trim content (remove all whitespace)
    local content=$(cat "$file" 2>/dev/null | tr -d '[:space:]')
    content=${content:-""}

    # Check if content matches hidden patterns
    if [[ "$content" == "hidden" ]] || [[ "$content" == "hidden;" ]] || [[ "$content" == "(hidden)" ]]; then
        return 0  # Is hidden
    fi

    return 1  # Not hidden
}

# Function to check if a component directory has all hidden files
# Sets global variables: COMPONENT_TOTAL_FILES, COMPONENT_HIDDEN_FILES
check_component() {
    local component_dir="$1"
    COMPONENT_TOTAL_FILES=0
    COMPONENT_HIDDEN_FILES=0

    # Use for loop with glob pattern instead of find with process substitution
    # This avoids bus errors on bash 3.2
    for file in "$component_dir"/*; do
        # Skip if no matches (glob didn't expand)
        [[ -e "$file" ]] || continue
        # Skip directories
        [[ -f "$file" ]] || continue

        COMPONENT_TOTAL_FILES=$((COMPONENT_TOTAL_FILES + 1))
        if is_hidden_file "$file"; then
            COMPONENT_HIDDEN_FILES=$((COMPONENT_HIDDEN_FILES + 1))
        fi
    done

    # Return 0 (true/remove) if ALL files are hidden and there's at least one file
    if [[ $COMPONENT_TOTAL_FILES -gt 0 ]] && [[ $COMPONENT_TOTAL_FILES -eq $COMPONENT_HIDDEN_FILES ]]; then
        return 0
    fi

    return 1
}

# Function to process a metadata type directory (lwc or aura)
process_type_directory() {
    local type_name="$1"
    local type_dir="$2"
    local temp_names_file="$3"

    if [[ ! -d "$type_dir" ]]; then
        return
    fi

    echo "Scanning $type_name components in $type_dir..."

    local removed_count=0
    local removed_files=0
    local skipped_count=0

    # Use for loop with glob pattern instead of find with process substitution
    # This avoids bus errors on bash 3.2
    for component_dir in "$type_dir"/*/; do
        # Skip if no matches (glob didn't expand)
        [[ -d "$component_dir" ]] || continue

        local component_name=$(basename "$component_dir")

        if check_component "$component_dir"; then
            # All files are hidden - remove the component
            removed_count=$((removed_count + 1))
            removed_files=$((removed_files + COMPONENT_TOTAL_FILES))

            # Store component name in temp file
            echo "$component_name" >> "$temp_names_file"

            if [[ "$DRY_RUN" == true ]]; then
                echo "  [DRY RUN] Would remove: $component_name ($COMPONENT_TOTAL_FILES files)"
            else
                rm -rf "$component_dir"
                echo "  Removed: $component_name ($COMPONENT_TOTAL_FILES files)"
            fi
        elif [[ $COMPONENT_HIDDEN_FILES -gt 0 ]]; then
            # Has some hidden files but not all - skip
            skipped_count=$((skipped_count + 1))
        fi
    done

    # Update global statistics based on type
    if [[ "$type_name" == "LWC" ]]; then
        lwc_removed_count=$removed_count
        lwc_removed_files=$removed_files
        lwc_skipped_count=$skipped_count
    elif [[ "$type_name" == "Aura" ]]; then
        aura_removed_count=$removed_count
        aura_removed_files=$removed_files
        aura_skipped_count=$skipped_count
    fi
}

# Main execution
echo "=============================================="
echo "Clean Managed Packages"
echo "=============================================="
echo

if [[ ! -d "$METADATA_DIR" ]]; then
    echo "Error: Metadata directory not found: $METADATA_DIR" >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN MODE - No files will be deleted"
    echo
fi

# Process LWC directory
process_type_directory "LWC" "$METADATA_DIR/main/default/lwc" "$TEMP_LWC_NAMES"
echo

# Process Aura directory
process_type_directory "Aura" "$METADATA_DIR/main/default/aura" "$TEMP_AURA_NAMES"
echo

# Print summary
echo "=============================================="
echo "Summary"
echo "=============================================="
echo

total_removed=$((lwc_removed_count + aura_removed_count))
total_files=$((lwc_removed_files + aura_removed_files))
total_skipped=$((lwc_skipped_count + aura_skipped_count))

if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN - The following would be removed:"
else
    echo "Removal complete:"
fi

echo
echo "LWC Components:"
if [[ $lwc_removed_count -gt 0 ]]; then
    echo "  Removed: $lwc_removed_count ($lwc_removed_files files)"

    # Show component names (up to 10)
    max_display=10
    count=0
    while IFS= read -r name; do
        if [[ $count -lt $max_display ]]; then
            echo "    - $name"
        fi
        count=$((count + 1))
    done < "$TEMP_LWC_NAMES"

    if [[ $lwc_removed_count -gt $max_display ]]; then
        remaining=$((lwc_removed_count - max_display))
        echo "    ... and $remaining more"
    fi
else
    echo "  Removed: 0"
fi
if [[ $lwc_skipped_count -gt 0 ]]; then
    echo "  Skipped (mixed content): $lwc_skipped_count"
fi

echo
echo "Aura Components:"
if [[ $aura_removed_count -gt 0 ]]; then
    echo "  Removed: $aura_removed_count ($aura_removed_files files)"

    # Show component names (up to 10)
    max_display=10
    count=0
    while IFS= read -r name; do
        if [[ $count -lt $max_display ]]; then
            echo "    - $name"
        fi
        count=$((count + 1))
    done < "$TEMP_AURA_NAMES"

    if [[ $aura_removed_count -gt $max_display ]]; then
        remaining=$((aura_removed_count - max_display))
        echo "    ... and $remaining more"
    fi
else
    echo "  Removed: 0"
fi
if [[ $aura_skipped_count -gt 0 ]]; then
    echo "  Skipped (mixed content): $aura_skipped_count"
fi

echo
echo "----------------------------------------------"
echo "Total Components Removed: $total_removed"
echo "Total Files Removed: $total_files"
if [[ $total_skipped -gt 0 ]]; then
    echo "Total Components Skipped: $total_skipped"
fi
echo "----------------------------------------------"

if [[ $total_removed -eq 0 ]]; then
    echo
    echo "No hidden managed package content found."
fi

exit 0
