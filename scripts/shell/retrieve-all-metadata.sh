#!/bin/bash

###############################################################################
# Comprehensive Metadata Retrieval Script
# 
# Purpose: Retrieves ALL metadata from a Salesforce org using dynamic discovery
# Usage: ./retrieve-all-metadata.sh -o <org-alias> [options]
# 
# This script:
#   1. Discovers all available metadata types in the org
#   2. Generates chunked package.xml files for efficient retrieval
#   3. Retrieves metadata in chunks to avoid timeouts
#   4. Implements intelligent retry logic for unsupported metadata types
#   5. Automatically excludes newly discovered unsupported types and retries
#   6. Handles installed packages separately
#   7. Post-processes the retrieved metadata
###############################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs"
TEMP_DIR="$LOGS_DIR/temp"

# Default values
ORG_ALIAS=""
export API_VERSION=""  # exported so generate-package-xml.js writes manifests at the same version
WAIT_TIME="60"
DRY_RUN=false
PARALLEL=false
SKIP_PACKAGES=false
SKIP_POSTPROCESS=false
CLEAN_START=false
KEEP_MANAGED_PACKAGES=false
MANIFEST_DIR="manifests"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 -o <org-alias> [options]" >&2
    echo
    echo "Required:"
    echo "   -o <alias>       Org alias to retrieve from"
    echo
    echo "Options:"
    echo "   -a <version>     API version (default: org's version)"
    echo "   -w <minutes>     Wait time for retrieval (default: 60)"
    echo "   --dry-run        Show what would be retrieved without executing"
    echo "   --parallel       Run chunk retrievals in parallel (faster but may fail)"
    echo "   --skip-packages  Skip retrieval of installed packages"
    echo "   --skip-postprocess Skip post-processing of metadata"
    echo "   --keep-managed-packages Preserve hidden managed package content (default: remove)"
    echo ""
    echo "   --clean-start    Remove existing metadata before retrieval"
    echo "   -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "   $0 -o PROD-ORG"
    echo "   $0 -o my-sandbox -w 120"
    echo "   $0 -o dev-org --dry-run"
    echo "   $0 -o prod --parallel --skip-packages"
    echo "   $0 -o prod --keep-managed-packages"
    echo
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

###############################################################################
# RETRY LOGIC IMPLEMENTATION (Phase 2)
# 
# The following functions implement intelligent retry logic for metadata retrieval:
# 
# 1. parse_retrieval_error(): Extracts unsupported metadata type names from error logs
#    - Handles multiple error message formats from Salesforce CLI
#    - Returns the problematic metadata type name for exclusion
# 
# 2. add_unsupported_type(): Dynamically updates metadata-config.json
#    - Adds newly discovered unsupported types to the configuration
#    - Creates backup of original configuration
#    - Maintains sorted list of unsupported types
# 
# 3. retry_chunk_with_exclusion(): Regenerates package.xml excluding problematic types
#    - Updates configuration with newly discovered unsupported types
#    - Regenerates package manifests using updated exclusion rules
#    - Integrates with existing filtering logic from Phase 1
# 
# 4. Enhanced retrieve_chunk(): Implements smart retry mechanism
#    - Attempts standard retrieval first
#    - On failure, parses error to identify unsupported types
#    - Automatically excludes problematic types and retries with clean manifest
#    - Limits retry attempts to prevent infinite loops (3 standard + 2 smart retries)
# 
# Benefits:
# - Automatically handles newly discovered unsupported metadata types
# - Reduces manual intervention required for failed retrievals
# - Maintains configuration state for future runs
# - Provides detailed logging of retry attempts and outcomes
###############################################################################

# Parse retrieval error to extract unsupported metadata types
parse_retrieval_error() {
    local error_log="$1"
    
    # Look for the specific error pattern: "The specified metadata type is unsupported: [typename]"
    local unsupported_type=$(grep -o "unsupported: \[.*\]" "$error_log" 2>/dev/null | sed 's/.*\[\(.*\)\].*/\1/' | head -1)
    
    # Alternative patterns for different error formats
    if [[ -z "$unsupported_type" ]]; then
        unsupported_type=$(grep -o "metadata type.*unsupported" "$error_log" 2>/dev/null | sed 's/.*metadata type \([^[:space:]]*\).*/\1/' | head -1)
    fi
    
    # Look for "Unsupported Metadata Type" pattern
    if [[ -z "$unsupported_type" ]]; then
        unsupported_type=$(grep -i "unsupported metadata type" "$error_log" 2>/dev/null | sed 's/.*[tT]ype[[:space:]]*[:]*[[:space:]]*\([^[:space:]]*\).*/\1/' | head -1)
    fi
    
    echo "$unsupported_type"
}

# Add unsupported type to metadata-config.json
add_unsupported_type() {
    local unsupported_type="$1"
    local config_file="$UTILS_DIR/metadata-config.json"
    
    log_info "Adding '$unsupported_type' to unsupported types in metadata-config.json"
    
    # Backup the original config
    cp "$config_file" "${config_file}.backup.$(date +%s)"
    
    # Use node to update the JSON file safely
    node -e "
        const fs = require('fs');
        const config = JSON.parse(fs.readFileSync('$config_file', 'utf8'));
        
        if (!config.unsupportedTypes.includes('$unsupported_type')) {
            config.unsupportedTypes.push('$unsupported_type');
            config.unsupportedTypes.sort();
            console.log('Added unsupported type: $unsupported_type');
        } else {
            console.log('Type already in unsupported list: $unsupported_type');
        }
        
        fs.writeFileSync('$config_file', JSON.stringify(config, null, 2) + '\n');
    " 2>/dev/null || {
        log_error "Failed to update metadata-config.json"
        return 1
    }
}

# Retry chunk with exclusion of problematic types
retry_chunk_with_exclusion() {
    local chunk="$1"
    local failed_type="$2"
    local attempt="$3"
    
    log_info "Regenerating chunk '$chunk' excluding unsupported type: $failed_type (attempt $attempt)"
    
    # Add the failed type to the config
    if ! add_unsupported_type "$failed_type"; then
        log_error "Failed to update configuration with unsupported type"
        return 1
    fi
    
    # Regenerate the package XML files with updated configuration
    local regenerate_cmd="node $UTILS_DIR/generate-package-xml.js --input $TEMP_DIR/metadata-types.json --output-dir $MANIFEST_DIR --logs-dir $LOGS_DIR"
    
    log_info "Regenerating package manifests with updated exclusions..."
    if ! $regenerate_cmd; then
        log_error "Failed to regenerate package manifests"
        return 1
    fi
    
    log_success "Package manifests regenerated excluding: $failed_type"
    return 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o)
            ORG_ALIAS="$2"
            shift 2
            ;;
        -a)
            API_VERSION="$2"
            shift 2
            ;;
        -w)
            WAIT_TIME="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES=true
            shift
            ;;
        --skip-postprocess)
            SKIP_POSTPROCESS=true
            shift
            ;;
        --clean-start)
            CLEAN_START=true
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
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$ORG_ALIAS" ]]; then
    log_error "Org alias is required (-o)"
    print_usage
    exit 1
fi

# Check for required utilities
check_requirements() {
    local missing_tools=()
    
    for tool in sf jq node; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check for helper scripts
    local required_scripts=(
        "$UTILS_DIR/metadata-discovery.sh"
        "$UTILS_DIR/generate-package-xml.js"
        "$UTILS_DIR/retrieve-packages.sh"
        "$UTILS_DIR/post-process-metadata.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_error "Required script not found: $script"
            exit 1
        fi
    done
}


# Step 1: Discover metadata types
discover_metadata() {
    log_info "Step 1: Discovering metadata types in org: $ORG_ALIAS"
    
    # Create temp directory and ensure we work from project root
    mkdir -p "$TEMP_DIR"
    cd "$PROJECT_ROOT"
    
    local cmd="$UTILS_DIR/metadata-discovery.sh -o \"$ORG_ALIAS\" -f $TEMP_DIR/metadata-types.json -l $LOGS_DIR"
    
    if [[ -n "$API_VERSION" ]]; then
        cmd="$cmd -a $API_VERSION"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY RUN] Would execute: $cmd"
        return 0
    fi
    
    if ! bash -c "$cmd"; then
        log_error "Failed to discover metadata types"
        exit 1
    fi
    
    log_success "Metadata discovery complete"
}

# Step 2: Generate package.xml files
generate_manifests() {
    log_info "Step 2: Generating package.xml manifests"
    
    # Create manifest directory in temp
    MANIFEST_DIR="$TEMP_DIR/manifests"
    mkdir -p "$MANIFEST_DIR"
    
    local cmd="node $UTILS_DIR/generate-package-xml.js --input $TEMP_DIR/metadata-types.json --output-dir $MANIFEST_DIR --logs-dir $LOGS_DIR"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY RUN] Would execute: $cmd"
        return 0
    fi
    
    if ! $cmd; then
        log_error "Failed to generate package.xml files"
        exit 1
    fi
    
    log_success "Package manifests generated"
}

# Step 3: Retrieve metadata in chunks
retrieve_metadata_chunks() {
    log_info "Step 3: Retrieving metadata in chunks"
    
    # Find all generated package files
    local package_files=($MANIFEST_DIR/package-*.xml)
    
    if [[ ${#package_files[@]} -eq 0 ]]; then
        log_error "No package.xml files found in $MANIFEST_DIR"
        exit 1
    fi
    
    log_info "Found ${#package_files[@]} package chunks to retrieve"
    
    local failed_chunks=()
    local success_count=0
    
    # Function to retrieve a single chunk
    retrieve_chunk() {
        local package_file=$1
        local chunk_name=$(basename "$package_file" .xml | sed 's/package-//')
        
        log_info "Retrieving chunk: $chunk_name"
        
        local cmd="sf project retrieve start"
        cmd="$cmd --manifest \"$package_file\""
        cmd="$cmd --target-org \"$ORG_ALIAS\""
        cmd="$cmd --wait $WAIT_TIME"
        
        if [[ "$DRY_RUN" == true ]]; then
            echo "  [DRY RUN] Would execute: $cmd"
            return 0
        fi
        
        # Create log file for this chunk
        local log_file="$LOGS_DIR/retrieval-${chunk_name}.log"
        
        # Try retrieval with intelligent retry logic
        local retry_count=0
        local max_retries=3
        local smart_retry_count=0
        local max_smart_retries=2
        
        while [[ $retry_count -lt $max_retries ]]; do
            if bash -c "$cmd" > "$log_file" 2>&1; then
                log_success "Successfully retrieved: $chunk_name"
                return 0
            else
                retry_count=$((retry_count + 1))
                
                # Check if this is an unsupported metadata type error that we can handle intelligently
                local unsupported_type=$(parse_retrieval_error "$log_file")
                
                if [[ -n "$unsupported_type" && $smart_retry_count -lt $max_smart_retries ]]; then
                    smart_retry_count=$((smart_retry_count + 1))
                    log_warning "Found unsupported metadata type: $unsupported_type (smart retry $smart_retry_count of $max_smart_retries)"
                    
                    # Try to regenerate the chunk excluding the problematic type
                    if retry_chunk_with_exclusion "$chunk_name" "$unsupported_type" "$smart_retry_count"; then
                        # Update the package file path to the newly generated one
                        package_file="$MANIFEST_DIR/package-${chunk_name}.xml"
                        
                        # Reset the basic retry count since we're trying with a cleaned manifest
                        retry_count=0
                        
                        log_info "Retrying chunk '$chunk_name' with updated manifest (excluding: $unsupported_type)"
                        continue
                    else
                        log_error "Failed to regenerate chunk with exclusions"
                    fi
                fi
                
                # Standard retry logic for other types of failures
                if [[ $retry_count -lt $max_retries ]]; then
                    if [[ -z "$unsupported_type" ]]; then
                        log_warning "Retrieval failed for $chunk_name, retry $retry_count of $max_retries"
                        sleep 10
                    else
                        log_warning "Cannot retry further - unsupported type '$unsupported_type' in chunk $chunk_name"
                        log_error "Check $log_file for details"
                        return 1
                    fi
                else
                    log_error "Failed to retrieve after $max_retries attempts: $chunk_name"
                    if [[ -n "$unsupported_type" ]]; then
                        log_error "Last failure was due to unsupported metadata type: $unsupported_type"
                    fi
                    log_error "Check $log_file for details"
                    return 1
                fi
            fi
        done
    }
    
    # Retrieve chunks (parallel or sequential)
    if [[ "$PARALLEL" == true ]]; then
        log_info "Running parallel retrieval (may be less stable)"
        
        for package_file in "${package_files[@]}"; do
            if [[ "$DRY_RUN" == false ]]; then
                retrieve_chunk "$package_file" &
            else
                retrieve_chunk "$package_file"
            fi
        done
        
        # Wait for all background jobs to complete
        if [[ "$DRY_RUN" == false ]]; then
            wait
        fi
    else
        log_info "Running sequential retrieval (more stable)"
        
        for package_file in "${package_files[@]}"; do
            if retrieve_chunk "$package_file"; then
                success_count=$((success_count + 1))
            else
                failed_chunks+=("$(basename "$package_file" .xml)")
            fi
        done
    fi
    
    # Report results
    if [[ ${#failed_chunks[@]} -gt 0 ]]; then
        log_warning "Failed to retrieve ${#failed_chunks[@]} chunks:"
        for chunk in "${failed_chunks[@]}"; do
            echo "  - $chunk"
            # Show error details for failed chunks
            local chunk_log="$LOGS_DIR/retrieval-${chunk}.log"
            if [[ -f "$chunk_log" ]]; then
                local unsupported_type=$(parse_retrieval_error "$chunk_log")
                if [[ -n "$unsupported_type" ]]; then
                    echo "    (Failed due to unsupported type: $unsupported_type)"
                fi
            fi
        done
    fi
    
    log_success "Retrieved $success_count of ${#package_files[@]} chunks"
    
    # Check if any new unsupported types were discovered during retry attempts
    local config_backup_files=("$UTILS_DIR"/metadata-config.json.backup.*)
    if [[ ${#config_backup_files[@]} -gt 0 && -f "${config_backup_files[0]}" ]]; then
        log_info "New unsupported metadata types were discovered and added to configuration during retry attempts"
        echo "  Check metadata-config.json for updated unsupported types list"
    fi
}

# Step 4: Retrieve installed packages
retrieve_packages() {
    if [[ "$SKIP_PACKAGES" == true ]]; then
        log_info "Skipping package retrieval (--skip-packages specified)"
        return 0
    fi
    
    log_info "Step 4: Retrieving installed packages"
    
    local cmd="$UTILS_DIR/retrieve-packages.sh -o \"$ORG_ALIAS\" -w $WAIT_TIME -p $TEMP_DIR/installed-packages.json -l $LOGS_DIR"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY RUN] Would execute: $cmd"
        return 0
    fi
    
    if ! bash -c "$cmd"; then
        log_warning "Package retrieval completed with warnings"
    else
        log_success "Package retrieval complete"
    fi
}


# Step 5: Post-process metadata
postprocess_metadata() {
    if [[ "$SKIP_POSTPROCESS" == true ]]; then
        log_info "Skipping post-processing (--skip-postprocess specified)"
        return 0
    fi

    log_info "Step 5: Post-processing retrieved metadata"

    local cmd="$UTILS_DIR/post-process-metadata.sh -d force-app"

    # Add --keep-managed-packages flag if set
    if [[ "$KEEP_MANAGED_PACKAGES" == true ]]; then
        cmd="$cmd --keep-managed-packages"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY RUN] Would execute: $cmd"
        return 0
    fi

    if ! bash -c "$cmd"; then
        log_warning "Post-processing completed with warnings"
    else
        log_success "Post-processing complete"
    fi
}


# Format code with Prettier
format_code() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY RUN] Would run: npm run prettier"
        return 0
    fi
    
    log_info "Step 6: Formatting code with Prettier..."
    
    if npm run prettier; then
        log_success "Code formatting complete"
    else
        log_warning "Code formatting completed with warnings"
    fi
}

# Generate final report
generate_final_report() {
    # Ensure logs directory exists
    mkdir -p "$LOGS_DIR"
    local report_file="$LOGS_DIR/retrieval-summary-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Metadata Retrieval Summary"
        echo "=========================="
        echo ""
        echo "Timestamp: $(date)"
        echo "Org Alias: $ORG_ALIAS"
        echo "API Version: ${API_VERSION:-default}"
        echo "Wait Time: $WAIT_TIME minutes"
        echo "Execution Mode: $([ "$PARALLEL" == true ] && echo "Parallel" || echo "Sequential")"
        echo ""
        
        # Check for retry information
        local config_backup_files=("$UTILS_DIR"/metadata-config.json.backup.*)
        if [[ ${#config_backup_files[@]} -gt 0 && -f "${config_backup_files[0]}" ]]; then
            echo "Retry Information:"
            echo "-----------------"
            echo "Smart retry logic was activated during retrieval"
            echo "New unsupported metadata types were discovered and excluded"
            echo "Configuration updated: metadata-config.json"
            echo "Backup created: $(basename "${config_backup_files[-1]}")"
            echo ""
        fi
        
        if [[ -d "force-app/main/default" ]]; then
            echo "Retrieved Components:"
            echo "--------------------"
            
            # Count files by extension
            echo "Apex Classes: $(find "force-app/main/default" -name "*.cls" 2>/dev/null | wc -l)"
            echo "Apex Triggers: $(find "force-app/main/default" -name "*.trigger" 2>/dev/null | wc -l)"
            echo "LWC Components: $(find "force-app/main/default" -path "*/lwc/*" -name "*.js" 2>/dev/null | wc -l)"
            echo "Flows: $(find "force-app/main/default" -name "*.flow-meta.xml" 2>/dev/null | wc -l)"
            echo "Custom Objects: $(find "force-app/main/default" -name "*.object-meta.xml" 2>/dev/null | wc -l)"
            echo "Profiles: $(find "force-app/main/default" -name "*.profile-meta.xml" 2>/dev/null | wc -l)"
            echo "Permission Sets: $(find "force-app/main/default" -name "*.permissionset-meta.xml" 2>/dev/null | wc -l)"
            echo ""
            echo "Total XML Files: $(find "force-app/main/default" -name "*.xml" 2>/dev/null | wc -l)"
            echo "Total Size: $(du -sh "force-app/main/default" 2>/dev/null | cut -f1)"
        else
            echo "Retrieved Components: NONE"
            echo "--------------------"
            echo "No force-app directory found - retrieval may have failed"
        fi
        
        echo ""
        echo "Force-App Status After Retrieval:"
        echo "-----------------------------"
        if [[ -d "force-app/main/default" ]]; then
            echo "Force-App Directories: $(find force-app/main/default -mindepth 1 -maxdepth 1 -type d | wc -l)"
            echo "Force-App Total Files: $(find force-app/main/default -type f | wc -l)"
            echo "Force-App Size: $(du -sh force-app 2>/dev/null | cut -f1)"
        else
            echo "Force-App: Not found"
        fi
    } > "$report_file"
    
    log_success "Summary report saved to: $report_file"
    
    # Always show the report (even in dry run for debugging)
    cat "$report_file"
}

# Main execution
main() {
    echo "==========================================================================="
    echo "Comprehensive Metadata Retrieval Script"
    echo "==========================================================================="
    echo ""
    
    # Check requirements
    check_requirements
    
    # Display configuration
    echo "Configuration:"
    echo "  Org Alias: $ORG_ALIAS"
    echo "  API Version: ${API_VERSION:-default}"
    echo "  Wait Time: $WAIT_TIME minutes"
    echo "  Dry Run: $DRY_RUN"
    echo "  Parallel: $PARALLEL"
    echo "  Skip Packages: $SKIP_PACKAGES"
    echo "  Skip Post-process: $SKIP_POSTPROCESS"
    echo "  Keep Managed Packages: $KEEP_MANAGED_PACKAGES"
    echo "  Clean Start: $CLEAN_START"
    echo ""
    
    # Start timer
    START_TIME=$(date +%s)
    
    # Execute steps
    discover_metadata
    generate_manifests
    retrieve_metadata_chunks
    retrieve_packages
    postprocess_metadata
    format_code
    
    # Calculate elapsed time
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))
    
    echo ""
    echo "==========================================================================="
    log_success "Metadata retrieval complete!"
    echo "Total time: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
    echo ""
    
    # Generate final report
    generate_final_report
    
    echo ""
    echo "Next steps:"
    echo "  1. Review the retrieval report for any issues"
    echo "  2. Check log files for failed chunks"
    echo "  3. Review retrieved metadata in force-app/ directory"
    echo "  4. Commit the updated metadata to your git repository"
    echo "  5. Create feature branches for development work"
    echo "==========================================================================="
}

# Run main function
main