#!/bin/bash

# cryptraid_assembler.sh


RAID_LEVEL=""
RAID_MEMBERS=()
MEMBER_COUNT=""
MEMBER_SIZE=""
MODE=""
PAYLOAD_FORGER=""
KEY_SPEC=""
KEYS=()
PARAMS_OUT_FILE="params.txt"
MAXDEPTH=1
RAID_NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 16 | head -n 1)
MEMBERS_DIR=""
MEMBER_KEYS=()
LAST_KEY=""
FILE_SYSTEM="ext4"
CONST_PICKER="const_picker/pick_const.sh"
LUKSIFIER="tools/luksifier.sh"
DEVICE_FORGER="tools/raid_partitioner.sh"
FILE_FORGER="tools/payload_forger.sh"


get_random_const() {
    local options=("e" "phi" "pi" "ln2" "ln10" "sqrt" "cbrt" "zeta" "catalan" "euler")
    local rand="${options[$((RANDOM % ${#options[@]}))]}"
    echo "$rand"
}

check_integer() {
    local CONST_NAME="$1"
    local RADICAND="$2"
    case "$CONST_NAME" in
        "sqrt"|"cbrt"|"zeta")
            local result
            case "$CONST_NAME" in
                "sqrt")
                    result=$(echo "scale=10; sqrt($RADICAND)" | bc)
                    ;;
                "cbrt")
                    result=$(echo "scale=10; e($RADICAND/3)" | bc)
                    ;;
                "zeta")
                    result="zeta($RADICAND)"
                    ;;
            esac
            if [[ "$result" =~ \.0+$ ]]; then
                return 0
            else
                return 1
            fi
            ;;
        *)
        ;;
    esac
}

get_random_radicand() {
    local radicand
    local operations
    while true; do
        radicand=$((RANDOM % 89 + 2))
        if check_integer "$operations" "$radicand"; then
            break
        fi
    done
    echo "$radicand"
}

generate_const_keys() {
    local CONST_NAME="$1"
    local RADICAND="$2"
    if [[ -z "$CONST_NAME" ]]; then
        CONST_NAME="$(get_random_const)"
        echo "Randomly selected constant: $CONST_NAME"
    fi
    case "$CONST_NAME" in
        pi|e|phi|ln2|ln10|catalan|euler)
            RADICAND=""
            ;;
        sqrt|cube)
            if [[ -z "$RADICAND" ]]; then
                RADICAND="--n $(get_random_radicand)"
            fi
            ;;
        zeta)
            if [[ -z "$RADICAND" ]]; then
                RADICAND="--n 3"
            fi
            ;;
        *)
            echo "Unsupported constant: $CONST_NAME" >&2
            return 1
            ;;
    esac
    hex1=$(printf "%04x" $((RANDOM % 65536)))
    hex2=$(printf "%04x" $((RANDOM % 65536)))
    pair="--const ${CONST_NAME} --start 0x${hex1} --length 0x${hex2} ${RADICAND}"
    KEY_LIST+=("$pair")
    echo "$pair" >> "${PARAMS_OUT_FILE}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--level)
                RAID_LEVEL="$2"
                shift 2
                ;;
            -d|--devices)
                shift
                MODE="device"
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
            -k|--keys)
                KEY_SPEC="$2"
                shift 2
                ;;
            -o|--out)
                PARAMS_OUT_FILE="$2"
                shift 2
                ;;
            -t|--fstype)
                FILE_SYSTEM="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

parse_args "$@"

if [[ -n "$PARAMS_OUT_FILE" ]]; then
    touch "${PARAMS_OUT_FILE}"
fi

if [[ "$MODE" == "device" ]]; then
    MEMBER_COUNT=${#RAID_MEMBERS[@]}
    PAYLOAD_FORGER="${DEVICE_FORGER}"
else
    MODE="file"
    MEMBERS_DIR=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 16 | head -n 1)
    if [[ -z "$MEMBER_COUNT" || -z "$MEMBER_SIZE" ]]; then
        echo "Error: In file mode, both --count and --size are required."
        exit 1
    fi
    for index in $(seq 0 $((MEMBER_COUNT - 1))); do
        MEMBER_NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 16 | head -n 1)
        RAID_MEMBERS+=("${MEMBER_NAME}")
    done
    PAYLOAD_FORGER="${FILE_FORGER}"
fi

if [[ "$KEY_SPEC" =~ ^dir:(.+)$ ]]; then
    KEY_DIR="${BASH_REMATCH[1]}"
    KEY_MODE="directory"
    FILES_NUM=$((${MEMBER_COUNT} + 1))
    mapfile -d '' -t KEY_FILES < <(find  "${KEY_DIR}" -maxdepth "${MAXDEPTH}" -type f -print0 2>/dev/null)
    KEY_LIST=($(printf "%s\0" "${KEY_FILES[@]}" | shuf -z -n "${FILES_NUM}" | xargs -0 -n1))

elif [[ "$KEY_SPEC" =~ ^const(:([^:]+))?(:([^:]+))?$ ]]; then
    CONST_NAME="${BASH_REMATCH[2]}"
    ARGUMENT="${BASH_REMATCH[4]}"
    KEY_MODE="const"
    if [[ -n "$CONST_NAME" && -n "$ARGUMENT" ]]; then
        if check_integer "${CONST_NAME}" "${ARGUMENT}"; then
            echo "Error: ${CONST_NAME}(${ARGUMENT}) = $ARGUMENT は整数です。安全のため終了します。"
            exit 1
        fi
    fi
    for ((index = 0; index < $((${MEMBER_COUNT} + 1)); index++)); do
        generate_const_keys ${CONST_NAME} ${ARGUMENT}
        mkdir -p "keys/${RAID_NAME}"
        echo -n "$(bash $CONST_PICKER ${KEY_LIST[$index]})" > "keys/${RAID_NAME}/${RAID_NAME}_$index"
        KEY_LIST[$index]="keys/${RAID_NAME}/${RAID_NAME}_$index"
    done
else
    echo "Error: Invalid key source. Use --keys dir:/path or --keys const[:name[:arg]]"
    exit 1
fi

echo -e "\n\033[1;34m=== RAID Setup Parameters ===\033[0m"
echo -e "\033[1;32mRAID Level       :\033[0m $RAID_LEVEL"
echo -e "\033[1;32mMember Count     :\033[0m $MEMBER_COUNT"
echo -e "\033[1;32mMember Size      :\033[0m ${MEMBER_SIZE:-"(auto/detected)"}"
echo -e "\033[1;32mMode             :\033[0m $MODE"
echo -e "\033[1;32mMembers:\033[0m"
for index in "${!RAID_MEMBERS[@]}"; do
    echo -e "  [\033[1;36m$index\033[0m] ${RAID_MEMBERS[$index]}"
done
echo -e "\033[1;32mPayload Forger   :\033[0m $PAYLOAD_FORGER"
echo -e "\033[1;32mKey mode         :\033[0m $KEY_MODE"
echo -e "\033[1;32mDetermined Const Keys:\033[0m"
for index in "${!KEY_LIST[@]}"; do
    echo -e "  [\033[1;36m$index\033[0m] ${KEY_LIST[$index]}"
done
echo -e "\033[1;34m==============================\033[0m"

if [[ "$MODE" == "device" ]]; then
    echo "WARNING: LUKS formatting will DESTROY ALL DATA on the following devices:"
    for dev in "${RAID_MEMBERS[@]}"; do
        echo "  - $dev"
    done
else
    total_mb=$(( MEMBER_SIZE * MEMBER_COUNT ))
    echo "INFO: This will create $MEMBER_COUNT file(s), each $MEMBER_SIZE MiB, total ${total_mb} MiB."
    echo "No actual devices will be touched."
fi

echo -n "Are you sure you want to continue? [yes/no] "
read -r answer
[[ "$answer" == "yes" ]] || exit 1

if [[ "$MODE" == "device" ]]; then
    source raid_partitioner.sh --devices ${RAID_MEMBERS[@]} || {
        echo "Error: payload_forger.sh failed."
        exit 1
    }
    for params in "${KEY_LIST[@]}"; do
        echo "$params"
    done
else
    source $PAYLOAD_FORGER \
        --directory "${MEMBERS_DIR}"    \
        --members "${RAID_MEMBERS[@]}"  \
        --count "${MEMBER_COUNT}"         \
        --size "${MEMBER_SIZE}"
    for index in "${!RAID_MEMBERS[@]}"; do
        RAID_MEMBERS[$index]="${MEMBERS_DIR}/${RAID_MEMBERS[$index]}"
    done
fi

for key in "${KEY_LIST[@]:0:$((${#KEY_LIST[@]} - 1))}"; do
    MEMBER_KEYS+=("$key")
done
LAST_KEY="${KEY_LIST[-1]}"

source $LUKSIFIER --members "${RAID_MEMBERS[@]}" --key-files "${MEMBER_KEYS[@]}" --raid-name "${RAID_NAME}"

echo "RAID_LEVEL: ${RAID_LEVEL}"
echo "MEMBER_COUNT: ${MEMBER_COUNT}"
echo "RAID_NAME: ${RAID_NAME}"
mapfile -t MEMBERS < <(ls /dev/mapper/${RAID_NAME}* 2>/dev/null | sort)
echo "Found MEMBERS: ${#MEMBERS[@]}"
printf ' - %s\n' "${MEMBERS[@]}"

mdadm --create --verbose --level="${RAID_LEVEL}" --raid-devices="${#MEMBERS[@]}" "/dev/md/${RAID_NAME}" "${MEMBERS[@]}"

echo -n "Waiting for /dev/md/${RAID_NAME} to appear"
for i in {1..20}; do
    if [[ -e "/dev/md/${RAID_NAME}" ]]; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 0.5
done

if [[ ! -e "/dev/md/${RAID_NAME}" ]]; then
    echo -e "\n❌ mdadm create appears to have failed or is delayed beyond timeout."
    exit 1
fi

cryptsetup luksFormat "/dev/md/${RAID_NAME}" --key-file="${LAST_KEY}" "${BATCH_MODE}"
cryptsetup open "/dev/md/${RAID_NAME}" "${RAID_NAME}" --key-file="${LAST_KEY}"

mkfs."${FILE_SYSTEM}" "/dev/mapper/${RAID_NAME}"
mkdir -p "/mnt/${RAID_NAME}"
mount "/dev/mapper/${RAID_NAME}" "/mnt/${RAID_NAME}"
