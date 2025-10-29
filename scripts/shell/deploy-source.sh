#!/bin/bash

# Occasionally the VS Code extensions stop working and we need to default to using the SFDC CLI
# directly to perform certain functions.

# This script will deploy specific source from an org.

sf project deploy start --source-dir $1 --ignore-conflicts
