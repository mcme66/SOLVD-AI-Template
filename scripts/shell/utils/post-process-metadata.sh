#!/bin/bash

###############################################################################
# Post-Process Metadata Script
# 
# Purpose: Cleans up and validates retrieved metadata
# Usage: ./post-process-metadata.sh [-d <metadata-dir>] [-r <report-file>]
###############################################################################

set -e

# Default values
METADATA_DIR="force-app"
REPORT_FILE="retrieval-report.txt"
CLEAN_PROFILES=true
CLEAN_PERMISSIONS=true
VALIDATE_STRUCTURE=true
LOGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)/logs"

print_usage() {
    echo "Usage: $0 [-d <metadata-dir>] [-r <report-file>] [-l <logs-dir>] [options]" >&2
    echo
    echo "   -d    Metadata directory (optional, defaults to force-app)"
    echo "   -r    Report file (optional, defaults to retrieval-report.txt)"
    echo "   -l    Logs directory (optional, defaults to <project_root>/logs)"
    echo "   --skip-profile-clean    Skip cleaning of Profile metadata"
    echo "   --skip-permission-clean Skip cleaning of PermissionSet metadata"
    echo "   --skip-validation       Skip structure validation"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d)
            METADATA_DIR="$2"
            shift 2
            ;;
        -r)
            REPORT_FILE="$2"
            shift 2
            ;;
        -l)
            LOGS_DIR="$2"
            shift 2
            ;;
        --skip-profile-clean)
            CLEAN_PROFILES=false
            shift
            ;;
        --skip-permission-clean)
            CLEAN_PERMISSIONS=false
            shift
            ;;
        --skip-validation)
            VALIDATE_STRUCTURE=false
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            print_usage
            exit 1
            ;;
    esac
done

# Create logs directory and set up logging
mkdir -p "$LOGS_DIR"

# Use logs directory for report if not explicitly specified
if [[ "$REPORT_FILE" == "retrieval-report.txt" ]]; then
    REPORT_FILE="$LOGS_DIR/retrieval-report-$(date +%Y%m%d-%H%M%S).txt"
fi

LOG_FILE="$LOGS_DIR/post-processing-$(date +%Y%m%d-%H%M%S).log"

# Function to log with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_with_timestamp "===================================================================="
log_with_timestamp "Post-Processing Retrieved Metadata"
log_with_timestamp "===================================================================="
log_with_timestamp "Metadata directory: $METADATA_DIR"
log_with_timestamp "Report file: $REPORT_FILE"
log_with_timestamp "Log file: $LOG_FILE"
log_with_timestamp ""

# Initialize report
echo "Metadata Retrieval Report" > "$REPORT_FILE"
echo "=========================" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to clean Profile metadata
clean_profiles() {
    local profile_dir="$1/main/default/profiles"
    
    if [[ ! -d "$profile_dir" ]]; then
        log_with_timestamp "  No profiles found to clean"
        return
    fi
    
    local profile_count=0
    local cleaned_count=0
    
    for profile in "$profile_dir"/*.profile-meta.xml; do
        if [[ -f "$profile" ]]; then
            profile_count=$((profile_count + 1))
            local profile_name=$(basename "$profile")
            
            
            # Remove system permissions and managed package references
            # This is a simplified example - you might need more sophisticated XML processing
            if command -v xmlstarlet &> /dev/null; then
                xmlstarlet ed -L \
                    -d "//userPermissions[name='ViewSetup']" \
                    -d "//userPermissions[name='ViewRoles']" \
                    -d "//userPermissions[name='ViewAllData']" \
                    -d "//userPermissions[name='ModifyAllData']" \
                    -d "//applicationVisibilities[application[contains(text(),'__')]]" \
                    -d "//classAccesses[apexClass[contains(text(),'__')]]" \
                    "$profile" 2>/dev/null || true
                
                cleaned_count=$((cleaned_count + 1))
                log_with_timestamp "    ✓ Cleaned: $profile_name"
            else
                log_with_timestamp "    ⚠ xmlstarlet not installed, skipping XML cleanup for $profile_name"
            fi
        fi
    done
    
    log_with_timestamp "  Cleaned $cleaned_count of $profile_count profiles"
    echo "Profile Cleaning: $cleaned_count of $profile_count profiles processed" >> "$REPORT_FILE"
}

# Function to clean PermissionSet metadata
clean_permission_sets() {
    local perm_dir="$1/main/default/permissionsets"
    
    if [[ ! -d "$perm_dir" ]]; then
        log_with_timestamp "  No permission sets found to clean"
        return
    fi
    
    local perm_count=0
    local cleaned_count=0
    
    for permset in "$perm_dir"/*.permissionset-meta.xml; do
        if [[ -f "$permset" ]]; then
            perm_count=$((perm_count + 1))
            local perm_name=$(basename "$permset")
            
            
            # Remove system permissions and managed package references
            if command -v xmlstarlet &> /dev/null; then
                xmlstarlet ed -L \
                    -d "//userPermissions[name='ViewSetup']" \
                    -d "//userPermissions[name='ViewAllData']" \
                    -d "//userPermissions[name='ModifyAllData']" \
                    -d "//classAccesses[apexClass[contains(text(),'__')]]" \
                    "$permset" 2>/dev/null || true
                
                cleaned_count=$((cleaned_count + 1))
                log_with_timestamp "    ✓ Cleaned: $perm_name"
            else
                log_with_timestamp "    ⚠ xmlstarlet not installed, skipping XML cleanup for $perm_name"
            fi
        fi
    done
    
    log_with_timestamp "  Cleaned $cleaned_count of $perm_count permission sets"
    echo "PermissionSet Cleaning: $cleaned_count of $perm_count permission sets processed" >> "$REPORT_FILE"
}

# Enhanced XML validation function
validate_xml_file() {
    local file="$1"
    local filename=$(basename "$file")
    
    # Skip validation for certain Salesforce files that may have naming conventions
    # that don't affect XML validity
    if [[ "$filename" == *" "* ]]; then
        # Files with spaces in names are typically Salesforce layout files
        # These are valid by Salesforce convention, so we validate the content
        if ! xmllint --noout "$file" 2>/dev/null; then
            return 1  # Content is invalid XML
        fi
        return 0  # Content is valid XML
    fi
    
    # For files without spaces, use standard XML validation
    xmllint --noout "$file" 2>/dev/null
}

# Function to validate metadata structure
validate_structure() {
    local base_dir="$1"
    local issues=0
    
    echo "Validating metadata structure..." >> "$REPORT_FILE"
    
    # Check for common metadata directories
    local expected_dirs=("classes" "triggers" "objects" "layouts" "flows" "permissionsets" "profiles")
    
    for dir in "${expected_dirs[@]}"; do
        if [[ -d "$base_dir/main/default/$dir" ]]; then
            local count=$(find "$base_dir/main/default/$dir" -name "*.xml" | wc -l)
            log_with_timestamp "    ✓ $dir: $count components"
            echo "  - $dir: $count components" >> "$REPORT_FILE"
        fi
    done
    
    # Check for empty XML files
    log_with_timestamp ""
    log_with_timestamp "  Checking for empty files..."
    local empty_files=$(find "$base_dir" -name "*.xml" -size 0)
    
    if [[ -n "$empty_files" ]]; then
        log_with_timestamp "    ⚠ Found empty XML files:"
        echo "$empty_files" | while read -r file; do
            log_with_timestamp "      - $file"
            echo "  Empty file: $file" >> "$REPORT_FILE"
            issues=$((issues + 1))
        done
    else
        log_with_timestamp "    ✓ No empty files found"
    fi
    
    # Check for files with invalid XML
    log_with_timestamp ""
    log_with_timestamp "  Checking for invalid XML..."
    local invalid_count=0
    local content_invalid_count=0
    local filename_issues_count=0
    
    if command -v xmllint &> /dev/null; then
        # Use proper file iteration to handle filenames with spaces
        while IFS= read -r -d '' xml_file; do
            local filename=$(basename "$xml_file")
            
            # Test the file with our enhanced validation
            if ! validate_xml_file "$xml_file"; then
                # Categorize the type of issue
                if [[ "$filename" == *" "* ]]; then
                    log_with_timestamp "    ⚠ Invalid XML content in file with spaces: $xml_file"
                    echo "  Invalid XML content (filename has spaces): $xml_file" >> "$REPORT_FILE"
                    content_invalid_count=$((content_invalid_count + 1))
                else
                    log_with_timestamp "    ⚠ Invalid XML: $xml_file"
                    echo "  Invalid XML: $xml_file" >> "$REPORT_FILE"
                fi
                invalid_count=$((invalid_count + 1))
            fi
        done < <(find "$base_dir" -name "*.xml" -print0)
        
        if [[ $invalid_count -eq 0 ]]; then
            log_with_timestamp "    ✓ All XML files are valid"
        else
            log_with_timestamp "    Found $invalid_count invalid XML files"
            if [[ $content_invalid_count -gt 0 ]]; then
                log_with_timestamp "      - $content_invalid_count files with content issues (despite having spaces in names)"
            fi
        fi
    else
        log_with_timestamp "    ⚠ xmllint not installed, skipping XML validation"
    fi
    
    return $issues
}

# Generate statistics
generate_statistics() {
    local base_dir="$1"
    
    echo "" >> "$REPORT_FILE"
    echo "Metadata Statistics" >> "$REPORT_FILE"
    echo "==================" >> "$REPORT_FILE"
    
    # Count by metadata type
    local total_files=$(find "$base_dir" -type f -name "*.xml" | wc -l)
    local total_size=$(du -sh "$base_dir" | cut -f1)
    
    echo "Total files: $total_files" >> "$REPORT_FILE"
    echo "Total size: $total_size" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    echo "Components by type:" >> "$REPORT_FILE"
    
    # Count specific types
    for ext in "cls" "trigger" "page" "component" "object" "layout" "flow-meta.xml"; do
        local count=$(find "$base_dir" -name "*.$ext" | wc -l)
        if [[ $count -gt 0 ]]; then
            echo "  - .$ext files: $count" >> "$REPORT_FILE"
        fi
    done
}

# Main execution
if [[ ! -d "$METADATA_DIR" ]]; then
    log_with_timestamp "✗ Error: Metadata directory not found: $METADATA_DIR"
    exit 1
fi

# Check if the main/default structure exists
if [[ ! -d "$METADATA_DIR/main/default" ]]; then
    log_with_timestamp "⚠ Warning: No Salesforce metadata structure found in $METADATA_DIR"
    log_with_timestamp "   This could indicate retrieval failures or empty results"
    echo "Warning: No metadata structure found in $METADATA_DIR" > "$REPORT_FILE"
    echo "This could indicate retrieval failures or that no metadata was retrieved." >> "$REPORT_FILE"
    log_with_timestamp "✓ Post-processing complete (no metadata to process)"
    exit 0
fi

# Clean profiles
if [[ "$CLEAN_PROFILES" == true ]]; then
    log_with_timestamp "Cleaning Profile metadata..."
    clean_profiles "$METADATA_DIR"
    log_with_timestamp ""
fi

# Clean permission sets
if [[ "$CLEAN_PERMISSIONS" == true ]]; then
    log_with_timestamp "Cleaning PermissionSet metadata..."
    clean_permission_sets "$METADATA_DIR"
    log_with_timestamp ""
fi

# Validate structure
if [[ "$VALIDATE_STRUCTURE" == true ]]; then
    log_with_timestamp "Validating metadata structure..."
    validate_structure "$METADATA_DIR"
    log_with_timestamp ""
fi

# Generate statistics
log_with_timestamp "Generating statistics..."
generate_statistics "$METADATA_DIR"

log_with_timestamp ""
log_with_timestamp "✓ Post-processing complete!"
log_with_timestamp "  Report saved to: $REPORT_FILE"
log_with_timestamp "  Log file: $LOG_FILE"

# Display summary
log_with_timestamp ""
log_with_timestamp "Summary:"
log_with_timestamp "--------"
tail -n 20 "$REPORT_FILE" | while read -r line; do
    log_with_timestamp "$line"
done