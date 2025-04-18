#!/bin/bash
# payload_forger.sh
# Generates encrypted LUKS volumes ("payloads") of specified size and count.
# Intended for secure transport or storage with plausible deniability.

MEMBERS_DIR=""
MEMBER_COUNT=""
MEMBER_SIZE="" # MiB
RAID_MEMBERS=()

parse_args() {

    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--directory)
                MEMBERS_DIR="$2"
                shift 2
                ;;
            -m|--members)
                shift
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    RAID_MEMBERS+=("$1")
                    shift
                done
                ;;
            -c|--count)
                MEMBER_COUNT="$2"
                shift 2
                ;;
            -s|--size)
                MEMBER_SIZE="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    if [[ -z "$MEMBER_COUNT" || -z "$MEMBER_SIZE" ]]; then
        echo "Error: In file mode, both --count and --size are required."
        exit 1
    fi
}

parse_args "$@"

mkdir -p "${MEMBERS_DIR}"

index=0
for MEMBER in ${RAID_MEMBERS[@]}; do
    echo -e "  [\033[1;36m$index\033[0m] forging ${MEMBER}"
    dd if=/dev/zero of="${MEMBERS_DIR}/${MEMBER}" bs=1M count="${MEMBER_SIZE}" status=none
    echo " - ${MEMBER}"
    ((index++))
done

echo "All members forged! Ready for mdadm setup."
echo "RAID devices: ${RAID_MEMBERS[*]}"

