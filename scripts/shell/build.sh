#!/bin/bash

# Build script for converting the source into the required artifact for the
# Metadata API.
DEPLOYMENT_NAME=''
MANIFEST_LOCATION=manifest/package.xml
BUILDS_DIRECTORY=builds
TMP_LOCATION=tmp_output
SOURCE_LOCATION=force-app

print_usage() {
    echo "Usage: $0 [-n -f -s]" >&2
    echo
    echo "   -n,    Deployment Name: Required"
    echo "   -f,    Manifest Location: default is manifest/package.xml"
    echo "   -s,    Source Location: default is force-app"
    echo
}

while getopts 'n:f:s:' flag; do
  case "${flag}" in
    n) DEPLOYMENT_NAME="${OPTARG}" ;;
    f) MANIFEST_LOCATION="${OPTARG}" ;;
    s) SOURCE_LOCATION="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

if [[ $DEPLOYMENT_NAME == '' ]]; then
    echo 'Please enter a Deployment Name (-n)'
    exit 1
fi

sf project convert source --root-dir "$SOURCE_LOCATION" \
                          --manifest "$MANIFEST_LOCATION" \
                          --output-dir "$TMP_LOCATION" \
                          --package-name "$DEPLOYMENT_NAME"

zip -r -X $DEPLOYMENT_NAME.zip $TMP_LOCATION

if [ ! -d "$BUILDS_DIRECTORY" ]; then
    mkdir $BUILDS_DIRECTORY
fi

mv $DEPLOYMENT_NAME.zip builds/$DEPLOYMENT_NAME.zip

rm -rf $TMP_LOCATION
