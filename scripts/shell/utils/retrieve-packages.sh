#!/bin/bash

###############################################################################
# Retrieve Installed Packages Script
# 
# Purpose: Retrieves metadata from all installed packages in an org
# Usage: ./retrieve-packages.sh -o <org-alias> [-d <output-dir>] [-w <wait-time>]
###############################################################################

set -e

# Default values
ORG_ALIAS=""
OUTPUT_DIR="force-app"
WAIT_TIME="60"
PACKAGES_FILE="installed-packages.json"
LOGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)/logs"

print_usage() {
    echo "Usage: $0 -o <org-alias> [-d <output-dir>] [-w <wait-time>] [-p <packages-file>] [-l <logs-dir>]" >&2
    echo
    echo "   -o    Org alias (required)"
    echo "   -d    Output directory (optional, defaults to force-app)"
    echo "   -w    Wait time in minutes (optional, defaults to 60)"
    echo "   -p    Packages JSON file (optional, defaults to installed-packages.json)"
    echo "   -l    Logs directory (optional, defaults to <project_root>/logs)"
    echo
}

# Parse command line arguments
while getopts 'o:d:w:p:l:h' flag; do
    case "${flag}" in
        o) ORG_ALIAS="${OPTARG}" ;;
        d) OUTPUT_DIR="${OPTARG}" ;;
        w) WAIT_TIME="${OPTARG}" ;;
        p) PACKAGES_FILE="${OPTARG}" ;;
        l) LOGS_DIR="${OPTARG}" ;;
        h) print_usage
           exit 0 ;;
        *) print_usage
           exit 1 ;;
    esac
done

# Validate required parameters
if [[ -z "$ORG_ALIAS" ]]; then
    echo "Error: Org alias is required (-o)" >&2
    print_usage
    exit 1
fi

# Create logs directory and set up logging
mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/package-retrieval-$(date +%Y%m%d-%H%M%S).log"

# Function to log with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_with_timestamp "===================================================================="
log_with_timestamp "Retrieving Installed Packages from: $ORG_ALIAS"
log_with_timestamp "===================================================================="

# Check if packages file exists
if [[ ! -f "$PACKAGES_FILE" ]]; then
    log_with_timestamp "Packages file not found. Querying org for installed packages..."
    
    PACKAGE_QUERY="SELECT Id, SubscriberPackage.Name, SubscriberPackage.NamespacePrefix FROM InstalledSubscriberPackage ORDER BY SubscriberPackage.Name"
    
    sf data query \
        --query "$PACKAGE_QUERY" \
        --target-org "$ORG_ALIAS" \
        --json \
        > "$PACKAGES_FILE" 2>> "$LOG_FILE"
    
    if [[ $? -ne 0 ]]; then
        log_with_timestamp "✗ Error: Failed to query installed packages"
        exit 1
    fi
fi

# Parse the packages file to get package names
PACKAGE_COUNT=$(jq '.result.totalSize' "$PACKAGES_FILE")

if [[ "$PACKAGE_COUNT" == "0" ]]; then
    log_with_timestamp "No installed packages found in the org."
    exit 0
fi

log_with_timestamp "Found $PACKAGE_COUNT installed packages"

# Extract package names and namespaces
PACKAGE_NAMES=$(jq -r '.result.records[] | .SubscriberPackage.NamespacePrefix // .SubscriberPackage.Name' "$PACKAGES_FILE" | tr '\n' ',' | sed 's/,$//')

# Remove any null values and empty strings
PACKAGE_NAMES=$(echo "$PACKAGE_NAMES" | sed 's/null,//g' | sed 's/,,/,/g' | sed 's/^,//' | sed 's/,$//')

if [[ -z "$PACKAGE_NAMES" ]]; then
    log_with_timestamp "⚠ Warning: Could not extract valid package names"
    log_with_timestamp "  Attempting to retrieve using package IDs instead..."
    
    # Try using package IDs as fallback
    PACKAGE_IDS=$(jq -r '.result.records[].Id' "$PACKAGES_FILE" | tr '\n' ',' | sed 's/,$//')
    
    if [[ -z "$PACKAGE_IDS" ]]; then
        log_with_timestamp "✗ Error: Could not extract package information"
        exit 1
    fi
    
    log_with_timestamp "Using package IDs: $PACKAGE_IDS"
    RETRIEVE_PARAM="$PACKAGE_IDS"
else
    log_with_timestamp "Package namespaces/names to retrieve: $PACKAGE_NAMES"
    RETRIEVE_PARAM="$PACKAGE_NAMES"
fi

# Create a subdirectory for package metadata
PACKAGE_OUTPUT_DIR="${OUTPUT_DIR}/installed-packages"
mkdir -p "$PACKAGE_OUTPUT_DIR"

log_with_timestamp ""
log_with_timestamp "Retrieving package metadata..."
log_with_timestamp "Output directory: $PACKAGE_OUTPUT_DIR"
log_with_timestamp "Wait time: $WAIT_TIME minutes"

# Retrieve the packages
PACKAGE_RETRIEVAL_LOG="$LOGS_DIR/package-retrieval-detailed-$(date +%Y%m%d-%H%M%S).log"

sf project retrieve start \
    --package-names "$RETRIEVE_PARAM" \
    --target-org "$ORG_ALIAS" \
    --output-dir "$PACKAGE_OUTPUT_DIR" \
    --wait "$WAIT_TIME" 2>&1 | tee "$PACKAGE_RETRIEVAL_LOG"

# Check the result
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    log_with_timestamp ""
    log_with_timestamp "✓ Package metadata retrieved successfully!"
    log_with_timestamp "  Location: $PACKAGE_OUTPUT_DIR"
    
    # Count retrieved components
    COMPONENT_COUNT=$(find "$PACKAGE_OUTPUT_DIR" -type f -name "*.xml" | wc -l)
    log_with_timestamp "  Components retrieved: $COMPONENT_COUNT"
else
    log_with_timestamp ""
    log_with_timestamp "⚠ Warning: Package retrieval completed with errors"
    log_with_timestamp "  Some packages may not have been retrieved"
    log_with_timestamp "  Check $PACKAGE_RETRIEVAL_LOG for details"
    
    # Try to retrieve packages one by one if bulk retrieval failed
    log_with_timestamp ""
    log_with_timestamp "Attempting individual package retrieval..."
    
    INDIVIDUAL_LOG="$LOGS_DIR/package-retrieval-individual-$(date +%Y%m%d-%H%M%S).log"
    
    IFS=',' read -ra PACKAGES <<< "$RETRIEVE_PARAM"
    for package in "${PACKAGES[@]}"; do
        if [[ -n "$package" ]]; then
            log_with_timestamp "  Retrieving: $package"
            sf project retrieve start \
                --package-names "$package" \
                --target-org "$ORG_ALIAS" \
                --output-dir "$PACKAGE_OUTPUT_DIR/$package" \
                --wait "$WAIT_TIME" 2>&1 | tee -a "$INDIVIDUAL_LOG"
            
            if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
                log_with_timestamp "    ✓ Success"
            else
                log_with_timestamp "    ✗ Failed"
            fi
        fi
    done
fi

log_with_timestamp ""
log_with_timestamp "Package retrieval process complete!"
log_with_timestamp "Log file: $LOG_FILE"