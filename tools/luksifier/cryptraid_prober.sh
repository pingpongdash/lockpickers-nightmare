#!/bin/bash

# cryptraid_prober.sh


MODE=""
MEMBERS_DIR=""
KEY_SPEC=""
PARAM_FILE=""
KEY_CANDIDATES_DIR=""
RAID_MEMBERS=()
CONST_PICKER="bash const_picker/pick_const.sh"
# CONST_PICKER="ruby const_picker/const_picker.rb"
KEY_FILES=()
MAXDEPTH=1
RAID_NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 16 | head -n 1)


parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--devices)
                shift
                MODE="device"
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    RAID_MEMBERS+=("$1")
                    shift
                done
                ;;
            -D|--dir)
                MEMBERS_DIR="$2"
                shift 2
                ;;
            -c|--candidates-dir)
                KEY_CANDIDATES_DIR="$2"
                shift 2
                ;;
            -p|--param-file)
                PARAM_FILE="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo "  -d, --devices <dev1> <dev2> ...   Use device mode"
                echo "  -D, --dir <path>                  Use directory mode"
                echo "  -c, --candidates-dir <path>       Path to key candidate files"
                echo "  -p, --param-file <file>           Path to parameter file"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

parse_args "$@"

if [[ -n "$PARAM_FILE" ]]; then
    echo "[*] Using parameter file: $PARAM_FILE"
    KEY_INDEX=0
    while IFS= read -r line; do
        KEYFILE="/tmp/keyfile_$KEY_INDEX.bin"
        echo -n "$($CONST_PICKER $line)" > "$KEYFILE"
        KEY_FILES+=("$KEYFILE")
        ((KEY_INDEX++))
    done < "$PARAM_FILE"
elif [[ -n "$KEY_CANDIDATES_DIR" ]]; then
    mapfile -d '' -t KEY_FILES < <(find "${KEY_CANDIDATES_DIR}" -maxdepth "$MAXDEPTH" -type f -print0 2>/dev/null)
fi

if [[ -n "${MEMBERS_DIR}" ]]; then
    mapfile -d '' -t RAID_MEMBERS < <(find  "${MEMBERS_DIR}" -maxdepth "${MAXDEPTH}" -type f -print0 2>/dev/null)
    printf "%s\n" "${RAID_MEMBERS[@]}"
fi

export MDADM_NO_MERGE=1

index=0
for MEMBER in "${RAID_MEMBERS[@]}"; do
    MEMBER_NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 16 | head -n 1)
    echo "Trying ${MEMBER} : with ${KEY_FILES[$index]}"
    if [ ! -e "${MEMBER}" ]; then
        echo "${MEMBER} not found."
        continue
        # exit 1
    fi
    for KEY_FILE in "${KEY_FILES[@]}"; do
        cryptsetup open "${MEMBER}" "${RAID_NAME}_${MEMBER_NAME}" --key-file="${KEY_FILE}" || {
            echo "    ❌ Unlock failed for this key"
            continue
        }
        echo "Waiting for /dev/md/${RAID_NAME} to appear"
        for i in {1..20}; do
            if [ -e "/dev/mapper/${RAID_NAME}_${MEMBER_NAME}" ]; then
                echo "    ✅ Successfully unlocked ${MEMBER} as ${RAID_NAME}_${MEMBER_NAME}"
                break 2
            fi
            echo -n "."
            sleep 0.5
        done
    done
    ((index++))
done

mapfile -t MEMBERS < <(ls /dev/mapper/${RAID_NAME}_* 2>/dev/null)
echo "Found members: ${#MEMBERS[@]}"
printf ' - %s\n' "${MEMBERS[@]}"

if [ -e "/dev/md127" ]; then
    echo "Stopping /dev/md127 ..."
    mdadm --stop /dev/md127
    sleep 1
fi

OLD_NAME=$(mdadm --examine /dev/mapper/${RAID_NAME}_* 2>/dev/null | \
    grep "Name :" | head -n1 | awk '{print $3}' | cut -d: -f2)
echo "OLD_NAME: ${OLD_NAME}"

echo "Assembling /dev/md/${RAID_NAME} ..."
mdadm --assemble "/dev/md/${RAID_NAME}" "${MEMBERS[@]}"

echo "Waiting for /dev/md/${RAID_NAME} to appear"
for i in {1..20}; do
    if [[ -e "/dev/md/${OLD_NAME}" ]]; then
        echo "Stopping /dev/md/${OLD_NAME} ..."
        mdadm --stop "/dev/md/${OLD_NAME}"
        sleep 1
    fi
    if [[ -e "/dev/md/${RAID_NAME}" ]]; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 0.5
done

if [ ! -e "/dev/md/${RAID_NAME}" ]; then
    echo "❌ mdadm --assemble failed. Checking RAID level..."
    RAID_LEVEL=$(mdadm --examine "${MEMBERS[0]}" 2>/dev/null | grep -i "Raid Level" | awk -F': ' '{print $2}')
    echo "RAID Level detected: $RAID_LEVEL"
    if [ "$RAID_LEVEL" != "raid0" ]; then
        echo "🔁 Retrying with --run ..."
        mdadm --assemble /dev/md/${RAID_NAME} "${MEMBERS[@]}" --run
    fi
    if [ ! -e "/dev/md/${RAID_NAME}" ]; then
        echo "❌ mdadm --assemble still failed after --run"
        exit 1
    fi
fi

for KEY_FILE in "${KEY_FILES[@]}"; do
    echo "Trying ${RAID_NAME}"
    cryptsetup open "/dev/md/${RAID_NAME}" "${RAID_NAME}" --key-file="${KEY_FILE}"
    if [ -e "/dev/mapper/${RAID_NAME}" ]; then
        echo "    ✅ Successfully unlocked ${RAID_NAME} as ${RAID_NAME}"
        mkdir -p "/mnt/${RAID_NAME}"
        mount "/dev/mapper/${RAID_NAME}" "/mnt/${RAID_NAME}"
        break
    else
        echo "    ❌ Unlock failed for this key"
    fi
done

cat /proc/mdstat
