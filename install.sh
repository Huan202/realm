#!/bin/bash

set -e

REPO_OWNER="${REALM_XWPF_REPO_OWNER:-Huan202}"
REPO_NAME="${REALM_XWPF_REPO_NAME:-realm}"
REPO_BRANCH="${REALM_XWPF_REPO_BRANCH:-main}"
RAW_URL="${REALM_XWPF_RAW_URL:-https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}}"
CACHE_BUST="${REALM_XWPF_CACHE_BUST:-$(date +%s)}"

TEMP_SCRIPT=$(mktemp) || exit 1
trap 'rm -f "$TEMP_SCRIPT"' EXIT

curl -fsSL --connect-timeout 10 --max-time 60 \
    "${RAW_URL}/xwPF.sh?ts=${CACHE_BUST}" -o "$TEMP_SCRIPT"

sudo REALM_XWPF_REPO_OWNER="$REPO_OWNER" \
    REALM_XWPF_REPO_NAME="$REPO_NAME" \
    REALM_XWPF_REPO_BRANCH="$REPO_BRANCH" \
    REALM_XWPF_CACHE_BUST="$CACHE_BUST" \
    bash "$TEMP_SCRIPT" install
