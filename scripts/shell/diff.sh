#!/bin/bash

# Generate a new Metadata Manifest file based on git diffs
# Uses the sfdx-git-delta CLI plugin (install once: sf plugins install sfdx-git-delta)
# https://github.com/scolladon/sfdx-git-delta

# After the build is generated, you will notice a git-ignored directory created at destructiveChanges/ (if you are
# building a destructive changeset). This can be deployed via the npm script 'deploy:destructive'

# NOTE: We assume that you want the final destination of the manifest file to be located
# at manifest/...

# Example Usage
# npm run diff -- -f 'HEAD^'
TO='HEAD'
FROM=''
MANIFEST='delta.xml'
DESTRUCTIVE='no'

print_usage() {
    echo "Usage: $0 [-f -t -m -d]" >&2
    echo
    echo "   -f,    Commit From: Expects a commit hash or branch name or valid git range. Required"
    echo "   -t,    Commit To: Default = HEAD"
    echo "   -m,    Name of the final output manifest file. Stored in the manifest/ directory. Default = delta.xml"
    echo "   -d,    Include a destructive change in the delta. Pass in 'y' if you're planning on deploying a destructive change. Default = 'no'"
    echo
}

while getopts 'f:t:m:d:' flag; do
  case "${flag}" in
    f) FROM="${OPTARG}" ;;
    t) TO="${OPTARG}" ;;
    m) MANIFEST="${OPTARG}" ;;
    d) DESTRUCTIVE="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

if [[ $FROM == '' ]]; then
    echo 'Please enter a commit / branch from which to run the diff'
    exit 1
fi

sf sgd source delta --to "$TO" \
					  --from "$FROM" \
					  --output-dir '.'

mv package/package.xml manifest/$MANIFEST
rm -r package/

if [[ $DESTRUCTIVE == 'no' || $DESTRUCTIVE == false || $DESTRUCTIVE == 'n' || $DESTRUCTIVE == 'false' ]]; then
	rm -r destructiveChanges/
fi
