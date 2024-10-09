#!/bin/zsh

IGNORE_USERS_WITHOUT_KEYS=true
DENOTE_OLD=true
OLDER_THAN_DATE=$(date +"%Y")  # i.e. "2024"

# Formatting
SPACING='    '
RAW_OLD_SYMBOL='*'
PRETTY=true
RED='\033[0;31m'
NC='\033[0m'  # No Color
BOLD='\033[1m'
UNDERLINE='\033[4m'

# Default values
DEFAULT_AWS_REGION='us-east-1'
DEFAULT_AWS_PROFILES=( default )

OUR_AWS_REGION="$DEFAULT_AWS_REGION"
OUR_AWS_PROFILES=("${DEFAULT_AWS_PROFILES[@]}")

# Display help function
usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -p, --profiles   Comma-separated list of AWS profiles (default: predefined profiles: ${DEFAULT_AWS_PROFILES[*]})"
    echo "  -r, --region     AWS region (default: $DEFAULT_AWS_REGION)"
    echo "  --raw            Disable all formatting"
    echo "  --raw-with-old   Disable all formatting except signify old"
    echo "  -h, --help       Display this help message"
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
        --raw) PRETTY=false; DENOTE_OLD=false ;;
        --raw-with-old) PRETTY=false ;;
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

# Function to get access keys for a user
get_access_keys() {
    local user=$1
    local profile=$2
    aws iam list-access-keys --user "$user" --profile "$profile" --region "$OUR_AWS_REGION" --no-cli-pager --query 'AccessKeyMetadata[*].AccessKeyId' --output text
}

# Function to get the last used date of an access key
get_last_used_date() {
    local key=$1
    local profile=$2
    aws iam get-access-key-last-used --access-key-id "$key" --profile "$profile" --region "$OUR_AWS_REGION" --no-cli-pager --query 'AccessKeyLastUsed.LastUsedDate' --output text | cut -d'T' -f1
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
    if $DENOTE_OLD && [[ ${date%%-*} -lt "$OLDER_THAN_DATE" ]]; then
        if $PRETTY; then
            echo "${SPACING}${SPACING}$key: ${RED}$date${NC}"
        else
            echo "${SPACING}${SPACING}$key: $date $RAW_OLD_SYMBOL"
        fi
    elif [[ -n $date ]]; then
        echo "${SPACING}${SPACING}$key: $date"
    else
        echo "${SPACING}${SPACING}$key: No date available"
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
        KEYS_LIST=( $(get_access_keys "$USER" "$PROF") )

        if [[ ${#KEYS_LIST[@]} -gt 0 || $IGNORE_USERS_WITHOUT_KEYS == false ]]; then
            print_user "$USER"
            if [[ -z "$KEYS_LIST" ]]; then
                echo "${SPACING}${SPACING}None"
            fi
        fi

        for KEY in "${KEYS_LIST[@]}"; do
            LAST_USED_DATE=$(get_last_used_date "$KEY" "$PROF")
            FORMATTED_DATE=${LAST_USED_DATE:-"Never Used"}

            print_key "$KEY" "$FORMATTED_DATE"
        done
    done

    $PRETTY && echo  # Blank line between profiles
done
