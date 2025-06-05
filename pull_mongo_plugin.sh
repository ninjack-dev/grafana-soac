#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="mongodb-datasource"

# Remove dist dir if exists
if [[ -d "$DIST_DIR" ]]; then
    rm -rf "$DIST_DIR"
fi

# Download latest release info
release_json="$(mktemp)"
curl -sSL "https://api.github.com/repos/haohanyang/mongodb-datasource/releases/latest" -o "$release_json"

# Find the zip asset's download URL
zip_url=$(jq -r '.assets[] | select(.content_type=="application/zip") | .browser_download_url' "$release_json")
zip_name=$(jq -r '.assets[] | select(.content_type=="application/zip") | .name' "$release_json")
rm "$release_json"

if [[ -z "$zip_url" ]]; then
    echo "No zip asset found."
    exit 1
fi

# Download the zip asset
zip_tmp=$(mktemp)
echo "Downloading $zip_name..."
curl -sSL "$zip_url" -o "$zip_tmp"

# Extract zip to current directory
echo "Extracting files to $DIST_DIR"
unzip -q "$zip_tmp"
rm "$zip_tmp"

# Rename extracted dir
if [[ -d "haohanyang-mongodb-datasource" ]]; then
    mv "haohanyang-mongodb-datasource" "$DIST_DIR"
fi

rm "$DIST_DIR/*darwin*" "$DIST_DIR/*arm*" "$DIST_DIR/*.exe" # Remove all executables that aren't x86 Linux

# Grant execute permissions to matching binaries
for bin in "$DIST_DIR"/gpx_mongodb_datasource_*; do
    if [[ -f "$bin" ]]; then
        chmod +x "$bin"
    fi
done
