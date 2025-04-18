#!/bin/bash
#
# luksifier.sh - Applies LUKS encryption to a set of RAID member devices.
#
# WARNING:
# This script will **completely wipe** all data on the specified devices
# and initialize them with LUKS (Linux Unified Key Setup) encryption.
#
# ⚠️ Use with extreme caution. You have been warned. ⚠️
#
# Usage example:
#   source luksifier.sh --members /dev/sdX /dev/sdY --key-files key1.png key2.png
#
# Arguments:
#   --members      Devices to be encrypted (RAID members). Multiple allowed.
#   --key-files    Files to be used as LUKS key material. Multiple allowed.
#   --raid-name    Required. Name for the resulting RAID device (e.g., "cryptarray").
#
# Dependencies:
#   - bash
#   - cryptsetup
#
# Disclaimer:
# This script is provided "as is" without warranty of any kind.
# You are fully responsible for any data loss resulting from its use.


RAID_MEMBERS=()
KEY_FILES=()
BATCH_MODE="--batch-mode"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --members)
                shift
                while [[ $# -gt 0 && "$1" != --* ]]; do
                    RAID_MEMBERS+=("$1")
                    shift
                done
                ;;
            --key-files)
                shift
                while [[ $# -gt 0 && "$1" != --* ]]; do
                    KEY_FILES+=("$1")
                    shift
                done
                ;;
            --raid-name)
                shift
                RAID_NAME="$1"
                shift
                ;;
            *)
                echo "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
}

parse_args "$@"


# Check if all required arguments are provided
if [[ ${#RAID_MEMBERS[@]} -eq 0 || ${#KEY_FILES[@]} -eq 0 || -z "$RAID_NAME" ]]; then
    echo "Error: Missing required arguments."
    echo "Usage: --members <RAID members> --key-files <key files> --raid-name <RAID name>"
    exit 1
fi

echo ${RAID_MEMBERS[@]}
echo ${KEY_FILES[@]}
echo ${RAID_NAME}

MEMBER_COUNT=${#RAID_MEMBERS[@]}

index=0
for MEMBER in "${RAID_MEMBERS[@]}"; do
    echo -e "  [\033[1;36m$index\033[0m] encryptng ${MEMBER} with ${KEY_FILES[$index]}"
    cryptsetup luksFormat "${BATCH_MODE}" "${MEMBER}" --key-file="${KEY_FILES[$index]}"
    cryptsetup open "${MEMBER}" "${RAID_NAME}_${index}" --key-file="${KEY_FILES[$index]}"
    ((index++))
done

