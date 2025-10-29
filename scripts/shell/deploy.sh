#!/bin/bash

# Deploy built artifact (built using build.sh) via the Metadata API to
# a Sandbox or Production org
DEPLOYMENT_NAME=''
TEST_LEVEL='RunLocalTests'
TESTS=''
CHECK_ONLY=true
VALIDATED_JOB_ID=''
ALIAS=''

BUILDS_DIRECTORY=builds

print_usage() {
    echo "Usage: $0 [-n -a -t -r -c -q]" >&2
    echo
    echo "   -n,    Deployment Name: Required"
    echo "   -a,    Alias for the username for the Org to which we are deploying"
    echo "   -t,    Test Level, defaults to RunLocalTests"
    echo "   -r,    Tests to Run, required if the Test Level = RunSpecifiedTests"
    echo "   -c,    Check-Only, defaults to true; Used to running validate-only deployments"
    echo "   -q,    Validated-Job ID, used when you're going to run a Quick-deploy after validating a deployment with Check-Only"
    echo
}

while getopts 'n:a:t:r:c:q:' flag; do
  case "${flag}" in
    n) DEPLOYMENT_NAME="${OPTARG}" ;;
    a) ALIAS="${OPTARG}" ;;
    t) TEST_LEVEL="${OPTARG}" ;;
    r) TESTS="${OPTARG}" ;;
    c) CHECK_ONLY="${OPTARG}";;
    q) VALIDATED_JOB_ID="${OPTARG}";;
    *) print_usage
       exit 1 ;;
  esac
done

if [[ $ALIAS == '' ]]; then
    echo 'Please enter an Alias for the Org that we are deploying to (-a).'
    exit 1
fi

if [[ $TEST_LEVEL == 'RunSpecifiedTests' && $TESTS == '' ]]; then
    echo 'Please enter Tests to Run (-r) when Test Level is RunSpecifiedTests.'
    exit 1
fi

if [[ $CHECK_ONLY == true || $CHECK_ONLY == 1 || $CHECK_ONLY == y || $CHECK_ONLY == 'true' ]]; then
    if [[ $DEPLOYMENT_NAME == '' ]]; then
        echo 'Please enter a Deployment Name (-n)'
        exit 1
    fi

    echo '>>> Running Check-only deployment'

    if [[ $TEST_LEVEL == 'RunSpecifiedTests' ]]; then
        echo ">>> Command: sf project deploy validate --metadata-dir $BUILDS_DIRECTORY/$DEPLOYMENT_NAME.zip --target-org $ALIAS --test-level $TEST_LEVEL --tests $TESTS --wait 5"
        sf project deploy validate --metadata-dir $BUILDS_DIRECTORY/$DEPLOYMENT_NAME.zip \
                                --target-org "$ALIAS" \
                                --test-level $TEST_LEVEL \
                                --tests $TESTS \
                                --wait 5
    else
        echo ">>> Command: sf project deploy validate --metadata-dir $BUILDS_DIRECTORY/$DEPLOYMENT_NAME.zip --target-org $ALIAS --test-level $TEST_LEVEL --wait 5"
        sf project deploy validate --metadata-dir $BUILDS_DIRECTORY/$DEPLOYMENT_NAME.zip \
                                --target-org "$ALIAS" \
                                --test-level $TEST_LEVEL \
                                --wait 5
    fi
else
    if [[ $VALIDATED_JOB_ID == '' ]]; then
        echo 'Please enter a Validated Job ID (-q)'
        exit 1
    fi

    echo ">>> Running full deployment with Job ID: $VALIDATED_JOB_ID"
    echo ">>> Command: sf project deploy quick --target-org $ALIAS --job-id $VALIDATED_JOB_ID"
    sf project deploy quick --target-org "$ALIAS" --job-id "$VALIDATED_JOB_ID"
fi
