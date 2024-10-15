#!/bin/zsh

DENOTE_OLD=true
IGNORE_INACTIVE_KEYS=false
IGNORE_USERS_WITHOUT_KEYS=true
DISABLE_AGE_FLAGS=false
DISABLE_STATUS_FLAGS=false
OLDER_THAN_DATE=$(date +"%Y")  # i.e. "2024"

# Formatting
PRETTY=false  # Default to raw mode
RAW_OLD_SYMBOL='*'
RAW_INACTIVE_SYMBOL='(I)'
SPACING='    '

BOLD='\033[1m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color
RED='\033[0;31m'
YELLOW='\033[1;33m'
UNDERLINE='\033[4m'

# Default values
OUR_AWS_REGION='us-east-1'
OUR_AWS_PROFILES=( default )

# Display help function
usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -p, --profiles                    Comma-separated list of AWS profiles (default: '${OUR_AWS_PROFILES[*]}')"
    echo "  -r, --region                      AWS region (default: '$OUR_AWS_REGION')"
    echo "  --pretty                          Enable pretty formatting"
    echo "  --ignore-inactive                 Ignore inactive access keys"
    echo "  --show-users-without-keys         Show users without access keys"
    echo "  --disable-age-flags               Disable old key age flags"
    echo "  --disable-status-flags            Disable active/inactive key flags"
    echo "  --disable-all-flags               Disable both age and status flags"
    echo "  -h, --help                        Display this help message"
    echo
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--profiles)
            profiles_input="$2"
            IFS=',' read -r -A OUR_AWS_PROFILES <<< "$profiles_input"  # Use -A for array assignment
            shift
            ;;
        -r|--region) OUR_AWS_REGION="$2"; shift ;;
        --pretty) PRETTY=true ;;
        --ignore-inactive) IGNORE_INACTIVE_KEYS=true ;;
        --show-users-without-keys) IGNORE_USERS_WITHOUT_KEYS=false ;;
        --disable-age-flags) DISABLE_AGE_FLAGS=true ;;
        --disable-status-flags) DISABLE_STATUS_FLAGS=true ;;
        --disable-all-flags) DISABLE_AGE_FLAGS=true; DISABLE_STATUS_FLAGS=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter: $1"; usage; exit 1 ;;
    esac
    shift
done

# Function to get all users in an account
get_users() {
    local profile=$1
    aws iam list-users --profile "$profile" --region "$OUR_AWS_REGION" --no-cli-pager --query 'Users[*].UserName' --output text
}

# Function to get access keys for a user, including status
get_access_keys() {
    local user=$1
    local profile=$2
    aws iam list-access-keys --user "$user" --profile "$profile" --region "$OUR_AWS_REGION" --no-cli-pager --query 'AccessKeyMetadata[*].[AccessKeyId,Status]' --output text
}

# Function to get the last used date of an access key
get_last_used_date() {
    local key=$1
    local profile=$2
    aws iam get-access-key-last-used --access-key-id "$key" --profile "$profile" --region "$OUR_AWS_REGION" --no-cli-pager --query 'AccessKeyLastUsed.LastUsedDate' --output text | cut -d'T' -f1
}

is_key_old() {
    [[ ${1%%-*} -lt "$OLDER_THAN_DATE" ]]
}

# Improved formatting output
print_header() {
    if $PRETTY; then
        echo "${BOLD}${UNDERLINE}$1${NC}"
    else
        echo "$1"
    fi
}

print_user() {
    echo "${SPACING}$1"
}

print_key() {
    local key=$1
    local date=$2
    local local_status=$3

    if $PRETTY; then
        # Determine colors
        local key_color=""
        if [[ $DISABLE_STATUS_FLAGS == false ]]; then
            if [[ "$local_status" == "Inactive" ]]; then
                key_color=$YELLOW
            else
                key_color=$GREEN
            fi
        fi

        local date_color=""
        if [[ $DISABLE_AGE_FLAGS == false ]]; then
                date_color=$RED
        fi

        if $DENOTE_OLD && is_key_old "$date"; then
            # Old Pretty
            echo "${SPACING}${SPACING}${key_color}$key${NC}: ${date_color}$date${NC}"  # Show in red
        else
            # Current Pretty
            echo "${SPACING}${SPACING}${key_color}$key${NC}: $date"
        fi
    else
        # Determine if age flag or status flag should be disabled
        local age_flag=$([[ $DISABLE_AGE_FLAGS == false ]] && echo " $RAW_OLD_SYMBOL" || echo "")
        local status_flag=$([[ $DISABLE_STATUS_FLAGS == false && "$local_status" == "Inactive" ]] && echo " $RAW_INACTIVE_SYMBOL" || echo "")

        if $DENOTE_OLD && is_key_old "$date"; then
            # Old Raw
            echo "${SPACING}${SPACING}$key: $date$status_flag$age_flag"
        else
            # Current Raw
            echo "${SPACING}${SPACING}$key: $date$status_flag"
        fi
    fi
}

# Main loop
for PROF in "${OUR_AWS_PROFILES[@]}"; do
    ACC_NUM=$(aws sts --profile "$PROF" get-caller-identity --query 'Account' --no-cli-pager --output text)
    print_header "$PROF ($ACC_NUM)"

    # Get all users in the account
    USER_NAMES=( $(get_users "$PROF") )

    if [[ -z "$USER_NAMES" ]]; then
        echo "${SPACING}No users found."
        continue
    fi

    # Get all keys for each user in the list
    for USER in "${USER_NAMES[@]}"; do
        # Get both access key ID and status
        KEYS_LIST=$(get_access_keys "$USER" "$PROF")

        if [[ -n "$KEYS_LIST" ]] || [[ $IGNORE_USERS_WITHOUT_KEYS == false ]]; then
            print_user "$USER"
        fi

        if [[ -z "$KEYS_LIST" ]]; then
            if [[ $IGNORE_USERS_WITHOUT_KEYS == false ]]; then
                echo "${SPACING}${SPACING}None"
            fi
            continue
        fi

        # Process each key and its status
        while IFS=$'\t' read -r KEY local_status; do
            if $IGNORE_INACTIVE_KEYS && [[ "$local_status" == "Inactive" ]]; then
                continue
            fi

            LAST_USED_DATE=$(get_last_used_date "$KEY" "$PROF")
            FORMATTED_DATE=${LAST_USED_DATE:-"Never Used"}

            print_key "$KEY" "$FORMATTED_DATE" "$local_status"
        done <<< "$KEYS_LIST"
    done

    $PRETTY && echo  # Blank line between profiles
done
