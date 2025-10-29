#!/bin/bash

# Occasionally the VS Code extensions stop working and we need to default to using the SFDC CLI
# directly to perform certain functions.

# This script will retrieve specific source from an org.

sf project retrieve start --source-dir $1
