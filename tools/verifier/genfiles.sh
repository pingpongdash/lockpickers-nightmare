#!/bin/bash


OUTPUT_DIR="$(pwd)/verify_files"
NUM_FILES=1000
MIN_SIZE=8192      # 8KB
MAX_SIZE=2097152   # 2MB

mkdir -p "$OUTPUT_DIR"

for i in $(seq -w 1 "$NUM_FILES"); do
    FILE_TYPE=$((RANDOM % 2))  # 0=bin, 1=text
    SIZE=$(shuf -i "$MIN_SIZE"-"$MAX_SIZE" -n 1)
    FILE_NAME="file_$i"

    if [[ $FILE_TYPE -eq 0 ]]; then
        # bin
        head -c "$SIZE" </dev/urandom > "$OUTPUT_DIR/${FILE_NAME}.bin"
    else
        # random text
        base64 </dev/urandom | head -c "$SIZE" > "$OUTPUT_DIR/${FILE_NAME}.txt"
    fi
done

cd "$OUTPUT_DIR"
sha256sum * > checksums.sha256

echo "Generated $NUM_FILES files (random sizes, mixed types) in $OUTPUT_DIR."
echo "Checksum file generated: $OUTPUT_DIR/checksums.sha256"
