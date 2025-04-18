#!/bin/bash

# raid_partitioner.sh
# Aligns multiple disks for RAID by calculating the minimum common size,
# applies GPT labels, and creates two partitions: one for RAID, one as buffer.

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

# Initialize maps for sector size, sector count, and total bytes
declare -A SECTOR_SIZE_MAP
declare -A SECTOR_COUNT_MAP
declare -A DISK_SIZE_BYTES
MIN_DISK_BYTES=""
RAID_MEMBERS=()
DISKS=()

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--devices)
                shift
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    DISKS+=("$1")
                    shift
                done
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

parse_args "$@"

echo "${DISKS[@]}"


# Analyze all disks to gather their sector info
for disk in "${DISKS[@]}"; do
    # Check if the disk or any of its partitions is mounted
    mount | awk '{print $1}' | grep -q "^${disk}" && {
        echo "Error: ${disk} or one of its partitions is mounted"
        exit 1
    }

    # Get logical sector size
    sector_size=$(cat /sys/block/$(basename "$disk")/queue/logical_block_size 2>/dev/null) || {
        echo "Failed to get sector size for $disk"
        exit 1
    }

    # Get total number of sectors
    total_sectors=$(sudo blockdev --getsz "$disk") || {
        echo "Failed to get sector count for $disk"
        exit 1
    }

    # Calculate total size in bytes
    total_bytes=$((sector_size * total_sectors))

    # Store results in associative arrays
    SECTOR_SIZE_MAP[$disk]=$sector_size
    SECTOR_COUNT_MAP[$disk]=$total_sectors
    DISK_SIZE_BYTES[$disk]=$total_bytes

    echo "$disk: $total_sectors sectors * $sector_size bytes = $total_bytes bytes"

    # Track minimum size among all disks (for consistent partitioning)
    if [[ -z "$MIN_DISK_BYTES" || $total_bytes -lt $MIN_DISK_BYTES ]]; then
        MIN_DISK_BYTES=$total_bytes
    fi
done

echo "Minimum usable disk size: $MIN_DISK_BYTES bytes"

# Reserve buffer space at the end of each disk (e.g. for metadata or alignment)
ADJUSTMENT_BUFFER_BYTES=$((128 * 1024 * 1024))
RAID_PARTITION_BYTES=$((MIN_DISK_BYTES - ADJUSTMENT_BUFFER_BYTES))

# Warn user and require confirmation
echo -n "WARNING: This will WIPE ALL DATA on ${DISKS[*]}! Continue? [yes/N] "
read -r confirm
[[ "$confirm" != "yes" ]] && { echo "Aborted"; exit 1; }

# Partition each disk with two partitions:
# 1. RAID partition (aligned start to buffer)
# 2. Adjustment/buffer partition (from buffer to end)
for disk in "${DISKS[@]}"; do
    sector_size=${SECTOR_SIZE_MAP[$disk]}
    total_sectors=${SECTOR_COUNT_MAP[$disk]}

    alignment_sectors=2048  # Typically 1 MiB alignment
    raid_sectors=$(( RAID_PARTITION_BYTES / sector_size ))
    raid_end_sector=$(( raid_sectors / alignment_sectors * alignment_sectors ))
    adjustment_buffer_sector=$(( (raid_end_sector + 1 + alignment_sectors - 1) / alignment_sectors * alignment_sectors ))

    echo "Partitioning $disk:"
    echo " - RAID partition: ${alignment_sectors}s to ${raid_end_sector}s"
    echo " - Buffer starts at: ${adjustment_buffer_sector}s"

    # Using 's' suffix to specify sectors explicitly
    parted --script "$disk" mklabel gpt || {
        echo "Failed to set GPT label on $disk"
        exit 1
    }

    parted --script "$disk" mkpart primary ${alignment_sectors}s ${raid_end_sector}s || {
        echo "Failed to create RAID partition on $disk"
        exit 1
    }

    parted --script "$disk" mkpart primary ${adjustment_buffer_sector}s 100% || {
        echo "Failed to create buffer partition on $disk"
        exit 1
    }
    raid_part="${disk}1"
    RAID_MEMBERS+=("$raid_part")
    echo " - $raid_part"
done

echo "All HDDs partitioned! Ready for mdadm setup."
echo "RAID devices: ${RAID_MEMBERS[*]}"

