#!/bin/bash

VERIFY_DIR="$(pwd)/verify_files"
CHECKSUM_FILE="${VERIFY_DIR}/checksums.sha256"
OK=true

if [ ! -f "$CHECKSUM_FILE" ]; then
  echo "❌ Checksum file not found: $CHECKSUM_FILE"
  exit 1
fi

while read -r line; do
  echo "$line"
  if [[ "$line" == *FAILED ]]; then
    echo "❌ Hash mismatch detected. Aborting verification."
    OK=false
    break
  fi
done < <(cd "$VERIFY_DIR" && sha256sum -c checksums.sha256)

if $OK; then
  echo "✅ All files verified successfully."
fi
