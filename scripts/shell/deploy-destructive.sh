#!/bin/bash

# This is a utility script for deploying a destructive Metadata API deployment to a Salesforce org
# It assumes that you've already generated the destructive deployment manifest files using the diff.sh script,
# and that you have the destructiveChanges/ directory with package.xml and destructiveChanges.xml files in it.

# This script also assumes that you're not deploying anything as part of this deployment, but that you're only
# deleting metadata from the production org.

# NOTE: This assumes that you have the sf v2 CLI installed. The v1 CLI command is the following if you need it:
# sfdx force:source:deploy -x package/package.xml --postdestructivechanges destructiveChanges/destructiveChanges.xml

# Example Overall Usage for Deploying a destructive metadata deployment:
# 	1. Commit all changes to ensure you're on a clean git working branch / status
# 	2. Delete the Apex classes or metadata that you'd like to purge
# 	3. Run `npm run diff` with the correct flags according to what you're trying to do
# 	4. Inspect the output found in the destrutiveChanges/ directory to ensure that it's what you want to deploy/delete
# 	5. Run this script using `npm run deploy:destructive`

# NOTE: Assuming that you're NOT deploying metadata (creating or updating) as part of this destructive deployment,
# then you can indeed ignore delta.xml file generated from the diff.sh script. You also do NOT need to run
# `npm run build` before running this script.

# Regarding the Apex Test Class that is indicated below: Basically, if you're going to be deploying any
# sort of destructive change to a production org that involves deleting Apex, tests will be run. So, instead of
# the default being running all local tests (which has a higher likelihood of failing), I'm specifying a single
# test class that I know will pass.

# TODO: We could likely update the deploy.sh script to allow for a destructive flag, and then get rid of this
# script entirely

ALIAS=''

print_usage() {
    echo "Usage: $0 [-a]" >&2
    echo
    echo "   -a,    Alias for the username for the Org to which we are deploying"
    echo
}

while getopts 'a:' flag; do
  case "${flag}" in
    a) ALIAS="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

if [[ $ALIAS == '' ]]; then
    echo 'Please enter an Alias for the Org that we are deploying to (-a).'
    exit 1
fi

sf project deploy start --manifest destructiveChanges/package.xml \
						--test-level RunSpecifiedTests \
						--tests "AsyncRequestTriggerHandler_Test" \
						--dry-run \
						--post-destructive-changes destructiveChanges/destructiveChanges.xml \
						--target-org "$ALIAS"
