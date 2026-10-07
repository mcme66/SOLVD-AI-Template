#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T=$(mktemp -d)
mkdir -p "$T/ok" "$T/bad"
printf '<ApexClass><apiVersion>67.0</apiVersion></ApexClass>' > "$T/ok/A.cls-meta.xml"
printf '<ApexClass><apiVersion>66.0</apiVersion></ApexClass>' > "$T/ok/B.cls-meta.xml"
printf '<ApexClass><apiVersion>68.0</apiVersion></ApexClass>' > "$T/bad/C.cls-meta.xml"
fail=0
"$HERE/check-api-version.sh" 67.0 "$T/ok/A.cls-meta.xml" "$T/ok/B.cls-meta.xml" || { echo "FAIL: ok files rejected"; fail=1; }
"$HERE/check-api-version.sh" 67.0 "$T/ok/A.cls-meta.xml" "$T/bad/C.cls-meta.xml" && { echo "FAIL: 68.0 accepted"; fail=1; }
"$HERE/check-api-version.sh" 67.0 && echo "no-files ok" || { echo "FAIL: empty list rejected"; fail=1; }
# Paths with spaces must not be split (CI pipes git diff -z through xargs -0)
mkdir -p "$T/with space"
printf '<Flow><apiVersion>68.0</apiVersion></Flow>' > "$T/with space/My Flow.flow-meta.xml"
printf '%s\0' "$T/ok/A.cls-meta.xml" "$T/with space/My Flow.flow-meta.xml" | xargs -0 "$HERE/check-api-version.sh" 67.0 && { echo "FAIL: spaced 68.0 file accepted"; fail=1; }
rm -rf "$T"; [ $fail -eq 0 ] && echo PASS; exit $fail
