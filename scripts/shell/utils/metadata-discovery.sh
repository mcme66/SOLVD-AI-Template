#!/bin/bash

###############################################################################
# Metadata Discovery Script
# 
# Purpose: Discovers all available metadata types in a Salesforce org
# Usage: ./metadata-discovery.sh -o <org-alias> [-a <api-version>]
###############################################################################

set -e

# Default values
ORG_ALIAS=""
API_VERSION=""
OUTPUT_FILE="metadata-types.json"
LOGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)/logs"

print_usage() {
    echo "Usage: $0 -o <org-alias> [-a <api-version>] [-f <output-file>] [-l <logs-dir>]" >&2
    echo
    echo "   -o    Org alias (required)"
    echo "   -a    API version (optional, defaults to org's version)"
    echo "   -f    Output file (optional, defaults to metadata-types.json)"
    echo "   -l    Logs directory (optional, defaults to <project_root>/logs)"
    echo
}

# Parse command line arguments
while getopts 'o:a:f:l:h' flag; do
    case "${flag}" in
        o) ORG_ALIAS="${OPTARG}" ;;
        a) API_VERSION="${OPTARG}" ;;
        f) OUTPUT_FILE="${OPTARG}" ;;
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

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Set up log files
LOG_FILE="$LOGS_DIR/metadata-discovery-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="$LOGS_DIR/metadata-discovery-errors.log"

# Function to log with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_with_timestamp "===================================================================="
log_with_timestamp "Metadata Discovery for org: $ORG_ALIAS"
log_with_timestamp "===================================================================="

# Build the command
CMD="sf org list metadata-types --target-org \"$ORG_ALIAS\" --json"

if [[ -n "$API_VERSION" ]]; then
    CMD="$CMD --api-version $API_VERSION"
fi

log_with_timestamp "Discovering metadata types..."
log_with_timestamp "Command: $CMD"

# Execute and save to file
eval $CMD > "$OUTPUT_FILE" 2>> "$ERROR_LOG"

# Check if the command was successful
if [ $? -eq 0 ]; then
    log_with_timestamp "✓ Metadata types discovered successfully"
    log_with_timestamp "  Output saved to: $OUTPUT_FILE"
    
    # Extract and display summary
    TOTAL_TYPES=$(jq '.result.metadataObjects | length' "$OUTPUT_FILE")
    log_with_timestamp "  Total metadata types found: $TOTAL_TYPES"
    
    # Discover members for metadata types that don't support wildcards
    log_with_timestamp "Discovering Lightning Web Component members..."
    
    # Create temp directory for member discovery
    TEMP_DIR=$(mktemp -d)
    
    # Fetch LWC members
    LWC_MEMBERS_FILE="$TEMP_DIR/lwc-members.json"
    sf org list metadata \
        --metadata-type LightningComponentBundle \
        --target-org "$ORG_ALIAS" \
        --json > "$LWC_MEMBERS_FILE" 2>> "$ERROR_LOG"
    
    if [ $? -eq 0 ]; then
        LWC_COUNT=$(jq '.result | length' "$LWC_MEMBERS_FILE" 2>/dev/null || echo "0")
        log_with_timestamp "  Found $LWC_COUNT Lightning Web Components"
        
        # Merge LWC members into main metadata file
        jq --slurpfile lwcs "$LWC_MEMBERS_FILE" \
            '.result.metadataObjects |= map(
                if .xmlName == "LightningComponentBundle" 
                then . + {members: $lwcs[0].result} 
                else . 
                end
            )' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    else
        log_with_timestamp "⚠ Warning: Could not retrieve LWC members"
    fi
    
    # Discover ALL CustomObject instances (both standard and custom)
    log_with_timestamp "Discovering all CustomObject instances..."
    
    CUSTOMOBJECT_MEMBERS_FILE="$TEMP_DIR/customobject-members.json"
    sf org list metadata \
        --metadata-type CustomObject \
        --target-org "$ORG_ALIAS" \
        --json > "$CUSTOMOBJECT_MEMBERS_FILE" 2>> "$ERROR_LOG"
    
    if [ $? -eq 0 ]; then
        OBJECT_COUNT=$(jq '.result | length' "$CUSTOMOBJECT_MEMBERS_FILE" 2>/dev/null || echo "0")
        CUSTOM_COUNT=$(jq '[.result[] | select(.fullName | endswith("__c"))] | length' "$CUSTOMOBJECT_MEMBERS_FILE" 2>/dev/null || echo "0")
        STANDARD_COUNT=$(jq '[.result[] | select(.fullName | endswith("__c") | not)] | length' "$CUSTOMOBJECT_MEMBERS_FILE" 2>/dev/null || echo "0")
        
        log_with_timestamp "  Found $OBJECT_COUNT total objects ($STANDARD_COUNT standard + $CUSTOM_COUNT custom)"
        
        # Merge CustomObject members into main metadata file
        jq --slurpfile objects "$CUSTOMOBJECT_MEMBERS_FILE" \
            '.result.metadataObjects |= map(
                if .xmlName == "CustomObject" 
                then . + {members: $objects[0].result} 
                else . 
                end
            )' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    else
        log_with_timestamp "⚠ Warning: Could not retrieve CustomObject members"
    fi
    
    # Discover ALL Report instances using SOQL (metadata API doesn't work well for folder-based reports)
    log_with_timestamp "Discovering all Report instances using SOQL..."

    REPORT_MEMBERS_FILE="$TEMP_DIR/report-members.json"

    # Query reports using SOQL - this is more reliable than metadata API for folder-based reports
    REPORT_QUERY="SELECT Id, Name, FolderName, DeveloperName FROM Report ORDER BY FolderName, Name"

    sf data query \
        --query "$REPORT_QUERY" \
        --target-org "$ORG_ALIAS" \
        --json > "$REPORT_MEMBERS_FILE" 2>> "$ERROR_LOG"

    if [ $? -eq 0 ]; then
        REPORT_COUNT=$(jq '.result.totalSize' "$REPORT_MEMBERS_FILE" 2>/dev/null || echo "0")
        log_with_timestamp "  Found $REPORT_COUNT reports using SOQL query"

        # Transform SOQL results into metadata API format for consistency
        jq '.result.records | map({
            "id": .Id,
            "fullName": (.FolderName + "/" + .DeveloperName),
            "fileName": ("reports/" + .FolderName + "/" + .DeveloperName),
            "type": "Report",
            "createdDate": null,
            "lastModifiedDate": null
        })' "$REPORT_MEMBERS_FILE" > "$REPORT_MEMBERS_FILE.transformed"

        # Merge Report members into main metadata file
        jq --slurpfile reports "$REPORT_MEMBERS_FILE.transformed" \
            '.result.metadataObjects |= map(
                if .xmlName == "Report"
                then . + {members: $reports[0]}
                else .
                end
            )' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    else
        log_with_timestamp "⚠ Warning: Could not retrieve Report members via SOQL"
    fi

    # Discover ALL Dashboard instances using SOQL (metadata API doesn't work well for folder-based dashboards)
    log_with_timestamp "Discovering all Dashboard instances using SOQL..."

    DASHBOARD_MEMBERS_FILE="$TEMP_DIR/dashboard-members.json"

    # Query dashboards using SOQL - this is more reliable than metadata API for folder-based dashboards
    DASHBOARD_QUERY="SELECT Id, Title, FolderName, DeveloperName FROM Dashboard ORDER BY FolderName, Title"

    sf data query \
        --query "$DASHBOARD_QUERY" \
        --target-org "$ORG_ALIAS" \
        --json > "$DASHBOARD_MEMBERS_FILE" 2>> "$ERROR_LOG"

    if [ $? -eq 0 ]; then
        DASHBOARD_COUNT=$(jq '.result.totalSize' "$DASHBOARD_MEMBERS_FILE" 2>/dev/null || echo "0")
        log_with_timestamp "  Found $DASHBOARD_COUNT dashboards using SOQL query"

        # Transform SOQL results into metadata API format for consistency
        jq '.result.records | map({
            "id": .Id,
            "fullName": (.FolderName + "/" + .DeveloperName),
            "fileName": ("dashboards/" + .FolderName + "/" + .DeveloperName),
            "type": "Dashboard",
            "createdDate": null,
            "lastModifiedDate": null
        })' "$DASHBOARD_MEMBERS_FILE" > "$DASHBOARD_MEMBERS_FILE.transformed"

        # Merge Dashboard members into main metadata file
        jq --slurpfile dashboards "$DASHBOARD_MEMBERS_FILE.transformed" \
            '.result.metadataObjects |= map(
                if .xmlName == "Dashboard"
                then . + {members: $dashboards[0]}
                else .
                end
            )' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    else
        log_with_timestamp "⚠ Warning: Could not retrieve Dashboard members via SOQL"
    fi

    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    # Query for installed packages
    echo ""
    log_with_timestamp "Discovering installed packages..."
    PACKAGE_QUERY="SELECT Id, SubscriberPackage.Name, SubscriberPackage.NamespacePrefix FROM InstalledSubscriberPackage ORDER BY SubscriberPackage.Name"
    
    # Store packages file in same directory as metadata types file
    PACKAGES_OUTPUT_FILE="$(dirname "$OUTPUT_FILE")/installed-packages.json"
    
    # Use set +e to allow this command to fail gracefully
    set +e
    sf data query \
        --query "$PACKAGE_QUERY" \
        --target-org "$ORG_ALIAS" \
        --json \
        > "$PACKAGES_OUTPUT_FILE" 2>> "$ERROR_LOG"
    QUERY_EXIT_CODE=$?
    set -e
    
    if [ $QUERY_EXIT_CODE -eq 0 ]; then
        PACKAGE_COUNT=$(jq '.result.totalSize' "$PACKAGES_OUTPUT_FILE" 2>/dev/null || echo "0")
        log_with_timestamp "✓ Found $PACKAGE_COUNT installed packages"
        log_with_timestamp "  Package list saved to: $PACKAGES_OUTPUT_FILE"
    else
        log_with_timestamp "⚠ Warning: Could not retrieve installed packages (may not be supported in this org)" | tee -a "$ERROR_LOG"
        # Create empty packages file so the rest of the script can continue
        echo '{"result":{"totalSize":0,"records":[]}}' > "$PACKAGES_OUTPUT_FILE"
        log_with_timestamp "  Created empty package list to continue processing"
    fi
    
else
    log_with_timestamp "✗ Error: Failed to discover metadata types" | tee -a "$ERROR_LOG"
    exit 1
fi

log_with_timestamp ""
log_with_timestamp "Discovery complete!"
log_with_timestamp "Log file: $LOG_FILE"
log_with_timestamp "Next steps:"
log_with_timestamp "  1. Run generate-package-xml.js to create package manifests"
log_with_timestamp "  2. Use retrieve-all-metadata.sh to retrieve the metadata"