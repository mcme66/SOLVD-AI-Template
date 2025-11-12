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
KEEP_MANAGED_PACKAGES=false
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
    echo "   --keep-managed-packages Preserve hidden managed package content (default: remove)"
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
        --keep-managed-packages)
            KEEP_MANAGED_PACKAGES=true
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

# Function to check if a file is hidden managed package content
is_hidden_file() {
    local file="$1"

    # Check if file exists and is a regular file
    if [[ ! -f "$file" ]]; then
        return 1  # Not hidden
    fi

    # Check file size (must be <= 10 bytes)
    local file_size=$(wc -c < "$file" 2>/dev/null || echo "999")
    if [[ $file_size -gt 10 ]]; then
        return 1  # Not hidden
    fi

    # Read and trim content (remove all whitespace)
    local content=$(cat "$file" 2>/dev/null | tr -d '[:space:]' || echo "")

    # Check if content matches hidden patterns
    if [[ "$content" == "hidden" ]] || [[ "$content" == "hidden;" ]] || [[ "$content" == "(hidden)" ]]; then
        return 0  # Is hidden
    fi

    return 1  # Not hidden
}

# Function to detect hidden managed package content
detect_hidden_managed_content() {
    local base_dir="$1"
    local report_file="$2"

    log_with_timestamp "Scanning for hidden managed package content..."

    # Directories to scan
    local scan_dirs=(
        "lwc"
        "aura"
        "classes"
        "triggers"
        "pages"
        "components"
    )

    # Arrays to store results
    declare -A hidden_components_by_type
    declare -A hidden_files_by_type
    declare -A hidden_size_by_type
    declare -A component_details

    local total_hidden_components=0
    local total_hidden_files=0
    local total_hidden_size=0

    # Scan each directory type
    for dir_type in "${scan_dirs[@]}"; do
        local full_dir="$base_dir/main/default/$dir_type"

        if [[ ! -d "$full_dir" ]]; then
            continue
        fi

        log_with_timestamp "  Scanning $dir_type..."

        local type_hidden_components=0
        local type_hidden_files=0
        local type_hidden_size=0

        # Find all subdirectories (components)
        while IFS= read -r -d '' component_dir; do
            local component_name=$(basename "$component_dir")
            local component_hidden_files=0
            local component_total_files=0
            local component_size=0
            local all_files_hidden=true

            # Check all files in the component
            while IFS= read -r -d '' file; do
                component_total_files=$((component_total_files + 1))

                if is_hidden_file "$file"; then
                    component_hidden_files=$((component_hidden_files + 1))
                    local file_size=$(wc -c < "$file" 2>/dev/null || echo "0")
                    component_size=$((component_size + file_size))
                else
                    all_files_hidden=false
                fi
            done < <(find "$component_dir" -maxdepth 1 -type f -print0 2>/dev/null)

            # If component has hidden files, record it
            if [[ $component_hidden_files -gt 0 ]]; then
                type_hidden_components=$((type_hidden_components + 1))
                type_hidden_files=$((type_hidden_files + component_hidden_files))
                type_hidden_size=$((type_hidden_size + component_size))

                # Store component details for reporting
                local detail_key="${dir_type}:${component_name}"
                component_details["$detail_key"]="$component_hidden_files files, $component_size bytes"

                if [[ "$all_files_hidden" == true ]] && [[ $component_total_files -gt 0 ]]; then
                    component_details["$detail_key"]="${component_details[$detail_key]} (ALL FILES HIDDEN)"
                fi
            fi
        done < <(find "$full_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

        # Store type-level statistics
        if [[ $type_hidden_components -gt 0 ]]; then
            hidden_components_by_type["$dir_type"]=$type_hidden_components
            hidden_files_by_type["$dir_type"]=$type_hidden_files
            hidden_size_by_type["$dir_type"]=$type_hidden_size

            total_hidden_components=$((total_hidden_components + type_hidden_components))
            total_hidden_files=$((total_hidden_files + type_hidden_files))
            total_hidden_size=$((total_hidden_size + type_hidden_size))

            log_with_timestamp "    Found $type_hidden_components hidden components with $type_hidden_files files"
        fi
    done

    # Generate detection report
    echo "" >> "$report_file"
    echo "================================================================================" >> "$report_file"
    echo "MANAGED PACKAGE DETECTION REPORT" >> "$report_file"
    echo "================================================================================" >> "$report_file"
    echo "" >> "$report_file"
    echo "Metadata Types Scanned:" >> "$report_file"
    echo "  - LightningComponentBundle (force-app/main/default/lwc)" >> "$report_file"
    echo "  - AuraDefinitionBundle (force-app/main/default/aura)" >> "$report_file"
    echo "  - ApexClass (force-app/main/default/classes)" >> "$report_file"
    echo "  - ApexTrigger (force-app/main/default/triggers)" >> "$report_file"
    echo "  - VisualforcePage (force-app/main/default/pages)" >> "$report_file"
    echo "  - VisualforceComponent (force-app/main/default/components)" >> "$report_file"
    echo "" >> "$report_file"

    if [[ $total_hidden_components -eq 0 ]]; then
        echo "Hidden Components Detected: NONE" >> "$report_file"
        echo "" >> "$report_file"
        echo "No hidden managed package content found." >> "$report_file"
        log_with_timestamp "  ✓ No hidden managed package content detected"
    else
        echo "Hidden Components Detected:" >> "$report_file"
        echo "" >> "$report_file"

        # Report by type
        for dir_type in "lwc" "aura" "classes" "triggers" "pages" "components"; do
            local component_count=${hidden_components_by_type[$dir_type]:-0}

            if [[ $component_count -gt 0 ]]; then
                local file_count=${hidden_files_by_type[$dir_type]}
                local size_bytes=${hidden_size_by_type[$dir_type]}

                # Type name mapping
                local type_name=""
                case "$dir_type" in
                    "lwc") type_name="LWC Components" ;;
                    "aura") type_name="Aura Components" ;;
                    "classes") type_name="Apex Classes" ;;
                    "triggers") type_name="Apex Triggers" ;;
                    "pages") type_name="Visualforce Pages" ;;
                    "components") type_name="Visualforce Components" ;;
                esac

                echo "  $type_name with Hidden Content: $component_count" >> "$report_file"

                # List up to 10 components per type
                local count=0
                local max_display=10

                for detail_key in "${!component_details[@]}"; do
                    if [[ "$detail_key" == "$dir_type:"* ]]; then
                        local comp_name="${detail_key#*:}"
                        local comp_info="${component_details[$detail_key]}"

                        if [[ $count -lt $max_display ]]; then
                            echo "    - $comp_name ($comp_info)" >> "$report_file"
                        fi

                        count=$((count + 1))
                    fi
                done

                if [[ $count -gt $max_display ]]; then
                    local remaining=$((count - max_display))
                    echo "    ... ($remaining more components)" >> "$report_file"
                fi

                echo "" >> "$report_file"
            fi
        done

        echo "Total Statistics:" >> "$report_file"
        echo "  Hidden Components: $total_hidden_components" >> "$report_file"
        echo "  Hidden Files: $total_hidden_files" >> "$report_file"

        # Convert bytes to KB for display
        local size_kb=$((total_hidden_size / 1024))
        if [[ $size_kb -eq 0 ]] && [[ $total_hidden_size -gt 0 ]]; then
            size_kb=1
        fi
        echo "  Total Size: ~${size_kb} KB" >> "$report_file"
        echo "" >> "$report_file"

        echo "Note: These are managed package components that cannot be modified." >> "$report_file"
        echo "By default, all detected hidden content will be automatically removed." >> "$report_file"
        echo "To preserve hidden content, use: --keep-managed-packages flag" >> "$report_file"

        log_with_timestamp "  ✓ Detected $total_hidden_components hidden components ($total_hidden_files files, ~${size_kb}KB)"
    fi

    echo "" >> "$report_file"
}

# Function to remove hidden managed package content
remove_hidden_managed_content() {
    local base_dir="$1"
    local report_file="$2"
    local keep_packages="${3:-false}"

    # Skip removal if flag is set
    if [[ "$keep_packages" == true ]]; then
        log_with_timestamp "  Skipping removal (--keep-managed-packages flag is set)"
        echo "" >> "$report_file"
        echo "================================================================================" >> "$report_file"
        echo "MANAGED PACKAGE REMOVAL REPORT" >> "$report_file"
        echo "================================================================================" >> "$report_file"
        echo "" >> "$report_file"
        echo "Removal Status: DISABLED (--keep-managed-packages flag was used)" >> "$report_file"
        echo "" >> "$report_file"
        echo "Hidden managed package content has been preserved." >> "$report_file"
        echo "To enable removal, run without the --keep-managed-packages flag." >> "$report_file"
        echo "" >> "$report_file"
        return 0
    fi

    log_with_timestamp "Removing hidden managed package content..."

    # Directories to scan
    local scan_dirs=(
        "lwc"
        "aura"
        "classes"
        "triggers"
        "pages"
        "components"
    )

    # Arrays to store removal results
    declare -A removed_components_by_type
    declare -A removed_files_by_type
    declare -A removed_size_by_type
    declare -A skipped_components_by_type
    declare -A removal_details

    local total_removed_components=0
    local total_removed_files=0
    local total_removed_size=0
    local total_skipped_components=0

    # Scan each directory type
    for dir_type in "${scan_dirs[@]}"; do
        local full_dir="$base_dir/main/default/$dir_type"

        if [[ ! -d "$full_dir" ]]; then
            continue
        fi

        log_with_timestamp "  Processing $dir_type..."

        local type_removed_components=0
        local type_removed_files=0
        local type_removed_size=0
        local type_skipped_components=0

        # Find all subdirectories (components)
        while IFS= read -r -d '' component_dir; do
            local component_name=$(basename "$component_dir")
            local component_files=0
            local component_hidden_files=0
            local component_size=0
            local all_files_hidden=true

            # Check all files in the component
            while IFS= read -r -d '' file; do
                component_files=$((component_files + 1))

                if is_hidden_file "$file"; then
                    component_hidden_files=$((component_hidden_files + 1))
                    local file_size=$(wc -c < "$file" 2>/dev/null || echo "0")
                    component_size=$((component_size + file_size))
                else
                    all_files_hidden=false
                fi
            done < <(find "$component_dir" -maxdepth 1 -type f -print0 2>/dev/null)

            # Only remove if ALL files are hidden
            if [[ "$all_files_hidden" == true ]] && [[ $component_files -gt 0 ]]; then
                # Remove the entire component directory
                rm -rf "$component_dir"

                type_removed_components=$((type_removed_components + 1))
                type_removed_files=$((type_removed_files + component_files))
                type_removed_size=$((type_removed_size + component_size))

                # Store removal details for reporting
                local detail_key="${dir_type}:${component_name}"
                removal_details["$detail_key"]="$component_files files, $component_size bytes"

                log_with_timestamp "    ✓ Removed: $component_name ($component_files files, $component_size bytes)"
            elif [[ $component_hidden_files -gt 0 ]]; then
                # Component has some hidden files but not all - skip it
                type_skipped_components=$((type_skipped_components + 1))
                log_with_timestamp "    ⊗ Skipped: $component_name (has $component_hidden_files hidden files, $((component_files - component_hidden_files)) non-hidden files)"
            fi
        done < <(find "$full_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

        # Store type-level statistics
        if [[ $type_removed_components -gt 0 ]] || [[ $type_skipped_components -gt 0 ]]; then
            removed_components_by_type["$dir_type"]=$type_removed_components
            removed_files_by_type["$dir_type"]=$type_removed_files
            removed_size_by_type["$dir_type"]=$type_removed_size
            skipped_components_by_type["$dir_type"]=$type_skipped_components

            total_removed_components=$((total_removed_components + type_removed_components))
            total_removed_files=$((total_removed_files + type_removed_files))
            total_removed_size=$((total_removed_size + type_removed_size))
            total_skipped_components=$((total_skipped_components + type_skipped_components))

            log_with_timestamp "    Removed $type_removed_components components ($type_removed_files files)"
            if [[ $type_skipped_components -gt 0 ]]; then
                log_with_timestamp "    Skipped $type_skipped_components components (mixed hidden/non-hidden content)"
            fi
        fi
    done

    # Generate removal report
    echo "" >> "$report_file"
    echo "================================================================================" >> "$report_file"
    echo "MANAGED PACKAGE REMOVAL REPORT" >> "$report_file"
    echo "================================================================================" >> "$report_file"
    echo "" >> "$report_file"
    echo "Removal Status: ENABLED (use --keep-managed-packages to disable)" >> "$report_file"
    echo "" >> "$report_file"

    if [[ $total_removed_components -eq 0 ]] && [[ $total_skipped_components -eq 0 ]]; then
        echo "No hidden managed package content found to remove." >> "$report_file"
        log_with_timestamp "  ✓ No hidden content found to remove"
    else
        if [[ $total_removed_components -gt 0 ]]; then
            echo "Removed Components:" >> "$report_file"
            echo "" >> "$report_file"

            # Report by type
            for dir_type in "lwc" "aura" "classes" "triggers" "pages" "components"; do
                local component_count=${removed_components_by_type[$dir_type]:-0}

                if [[ $component_count -gt 0 ]]; then
                    # Type name mapping
                    local type_name=""
                    case "$dir_type" in
                        "lwc") type_name="LWC" ;;
                        "aura") type_name="Aura" ;;
                        "classes") type_name="Apex Classes" ;;
                        "triggers") type_name="Apex Triggers" ;;
                        "pages") type_name="Visualforce Pages" ;;
                        "components") type_name="Visualforce Components" ;;
                    esac

                    echo "  $type_name:" >> "$report_file"

                    # List up to 10 components per type
                    local count=0
                    local max_display=10

                    for detail_key in "${!removal_details[@]}"; do
                        if [[ "$detail_key" == "$dir_type:"* ]]; then
                            local comp_name="${detail_key#*:}"
                            local comp_info="${removal_details[$detail_key]}"

                            if [[ $count -lt $max_display ]]; then
                                echo "    ✓ Removed $comp_name ($comp_info)" >> "$report_file"
                            fi

                            count=$((count + 1))
                        fi
                    done

                    if [[ $count -gt $max_display ]]; then
                        local remaining=$((count - max_display))
                        echo "    ... ($remaining more components removed)" >> "$report_file"
                    fi

                    echo "" >> "$report_file"
                fi
            done
        fi

        if [[ $total_skipped_components -gt 0 ]]; then
            echo "Skipped Components: $total_skipped_components" >> "$report_file"
            echo "  (Components with mixed hidden/non-hidden files were preserved)" >> "$report_file"
            echo "" >> "$report_file"
        fi

        echo "Summary:" >> "$report_file"
        echo "  Total Components Removed: $total_removed_components" >> "$report_file"
        echo "  Total Files Removed: $total_removed_files" >> "$report_file"

        # Convert bytes to KB for display
        local size_kb=$((total_removed_size / 1024))
        if [[ $size_kb -eq 0 ]] && [[ $total_removed_size -gt 0 ]]; then
            size_kb=1
        fi
        echo "  Total Size Freed: ~${size_kb} KB" >> "$report_file"

        if [[ $total_skipped_components -gt 0 ]]; then
            echo "  Total Components Skipped: $total_skipped_components" >> "$report_file"
        fi

        if [[ $total_removed_components -gt 0 ]]; then
            echo "  Repository Status: CLEAN ✓" >> "$report_file"
        fi

        log_with_timestamp "  ✓ Removed $total_removed_components components ($total_removed_files files, ~${size_kb}KB)"
        if [[ $total_skipped_components -gt 0 ]]; then
            log_with_timestamp "  ⊗ Skipped $total_skipped_components components (mixed content)"
        fi
    fi

    echo "" >> "$report_file"
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

# Detect hidden managed package content (Phase 1: Detection)
log_with_timestamp "Detecting hidden managed package content..."
detect_hidden_managed_content "$METADATA_DIR" "$REPORT_FILE"
log_with_timestamp ""

# Remove hidden managed package content (Phase 2: Removal)
log_with_timestamp "Processing hidden managed package content..."
remove_hidden_managed_content "$METADATA_DIR" "$REPORT_FILE" "$KEEP_MANAGED_PACKAGES"
log_with_timestamp ""

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