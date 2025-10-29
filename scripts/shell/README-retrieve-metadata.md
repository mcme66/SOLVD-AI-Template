# Comprehensive Metadata Retrieval Scripts

This directory contains a suite of scripts for comprehensive Salesforce metadata retrieval, designed for robust DevOps practices.

## Quick Start

### Basic Usage

```bash
# Retrieve all metadata from production org
./retrieve-all-metadata.sh -o "PROD SOLVD"

# Retrieve from sandbox with extended timeout
./retrieve-all-metadata.sh -o my-sandbox -w 120

# Dry run to see what would be retrieved
./retrieve-all-metadata.sh -o my-org --dry-run
```

### Prerequisites

- Salesforce CLI (`sf`) installed and authenticated to target org
- Node.js (for package.xml generation)
- `jq` for JSON parsing
- Optional: `xmlstarlet` for advanced XML cleaning

## Scripts Overview

### Main Script

- **`retrieve-all-metadata.sh`** - Primary orchestration script

### Utility Scripts

- **`utils/metadata-discovery.sh`** - Discovers available metadata types
- **`utils/generate-package-xml.js`** - Creates chunked package.xml files
- **`utils/retrieve-packages.sh`** - Handles installed package retrieval
- **`utils/post-process-metadata.sh`** - Cleans and validates metadata

## Key Features

### ✅ Complete Coverage

- Dynamically discovers ALL metadata types in the org
- Handles 470+ metadata types across all categories
- Special handling for packages, profiles, and settings

### ✅ Large Org Support

- Chunked retrieval prevents timeouts
- Configurable wait times (default: 60 minutes)
- Retry logic for failed retrievals
- Optional parallel processing

### ✅ Production Ready

- Comprehensive error handling and logging
- Detailed progress reporting
- Backup creation before modifications
- Extensive validation and cleanup

### ✅ DevOps Optimized

- Source format output (git-friendly)
- Automatic profile/permission set cleaning
- Smart .forceignore patterns
- Integration with existing build scripts

## Advanced Usage

### Custom Configuration

```bash
# Clean start with custom directory
./retrieve-all-metadata.sh -o prod --clean-start -d ./prod-backup

# Parallel retrieval (faster but less stable)
./retrieve-all-metadata.sh -o dev-org --parallel

# Skip packages and post-processing
./retrieve-all-metadata.sh -o sandbox --skip-packages --skip-postprocess
```

### Individual Utilities

```bash
# Just discover metadata types
./utils/metadata-discovery.sh -o my-org -a 61.0

# Generate package.xml files only
node ./utils/generate-package-xml.js --input metadata-types.json

# Retrieve packages only
./utils/retrieve-packages.sh -o my-org

# Post-process existing metadata
./utils/post-process-metadata.sh -d force-app
```

## Output Structure

After running the main script, you'll have:

```
force-app/
├── main/default/
│   ├── classes/          # Apex classes
│   ├── triggers/         # Apex triggers
│   ├── objects/          # Custom objects
│   ├── flows/            # Flow definitions
│   ├── layouts/          # Page layouts
│   ├── permissionsets/   # Permission sets (cleaned)
│   ├── profiles/         # Profiles (cleaned)
│   └── ...               # All other metadata types
├── installed-packages/   # Metadata from installed packages
└── ...

manifests/                # Generated package.xml files
├── package-code.xml
├── package-objects.xml
├── package-automation.xml
└── ...

docs/
└── metadata-coverage.md  # Documentation on supported/unsupported types

retrieval-*.log          # Detailed logs for each chunk
retrieval-summary-*.txt  # Final summary report
```

## Troubleshooting

### Common Issues

**Timeout Errors:**

```bash
# Increase wait time
./retrieve-all-metadata.sh -o my-org -w 120
```

**Large Org Performance:**

```bash
# Use parallel processing (less stable but faster)
./retrieve-all-metadata.sh -o my-org --parallel
```

**Permission Issues:**

```bash
# Ensure you're authenticated to the org
sf org display --target-org my-org
```

**Missing Tools:**

```bash
# Install required tools
npm install -g @salesforce/cli
brew install jq xmlstarlet  # macOS
```

### Log Files

- `retrieval-<chunk>.log` - Detailed output for each chunk
- `package-retrieval.log` - Package retrieval details
- `retrieval-summary-*.txt` - Overall summary and statistics

## Integration with Existing Scripts

This retrieval system complements your existing deployment scripts:

1. **Retrieve** metadata with `retrieve-all-metadata.sh`
2. **Build** deployment packages with `build.sh`
3. **Deploy** to target orgs with `deploy.sh`

## Best Practices

### For Production Orgs

- Always test the process on a sandbox first
- Use the `--dry-run` flag to preview actions
- Schedule retrievals during low-usage periods
- Monitor log files for any partial failures

### For Development Workflow

1. Retrieve from production: `./retrieve-all-metadata.sh -o prod`
2. Create feature branch: `git checkout -b feature/new-functionality`
3. Work in source-controlled sandbox
4. Retrieve changes: `./retrieve-all-metadata.sh -o dev-sandbox`
5. Deploy to production: Use existing `deploy.sh` workflow

### For Disaster Recovery

- Regular automated backups using this script
- Store metadata in version control
- Document any manual configurations not covered by metadata API

---

For detailed metadata coverage information, see `docs/metadata-coverage.md`.
