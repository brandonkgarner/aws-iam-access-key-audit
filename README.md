# aws-iam-access-key-audit

This script will find all IAM users across multiple AWS accounts and report their associated access keys with last usage dates. It will compare the last usage to a date and signify it hasn't been used in some time. 

AWS profiles should already be configured on the machine.

**Default is "Has been used in the current year"**.

## Usage

### Options
    -p, --profiles                    Comma-separated list of AWS profiles (default: '${OUR_AWS_PROFILES[*]}')"
    -r, --region                      AWS region (default: '$OUR_AWS_REGION')"
    --pretty                          Enable pretty formatting"
    --ignore-inactive                 Ignore inactive access keys"
    --show-users-without-keys         Show users without access keys"
    --disable-age-flags               Disable old key age flags"
    --disable-status-flags            Disable active/inactive key flags"
    --disable-all-flags               Disable both age and status flags"
    -h, --help                        Display this help message"

### Examples
- `./iam_keys_audit.sh -p dev,qa`

    ```
    dev (012345678901)
        dev-user-1
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08
        dev-user-2
            AKIAXXXXXXXXXXXXXXXX: 2022-10-01 (I) *
    qa (012345678902)
        qa-user-1
            AKIAXXXXXXXXXXXXXXXX: None *
    ```

- `./iam_keys_audit.sh -p dev,qa --ignore-inactive`

    ```
    dev (012345678901)
        dev-user-1
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08
    qa (012345678902)
        qa-user-1
            AKIAXXXXXXXXXXXXXXXX: None *
    ```
  
- `./iam_keys_audit.sh -p dev,qa --disable-all-flags`

    ```
    dev (012345678901)
        dev-user-1
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08
        dev-user-2
            AKIAXXXXXXXXXXXXXXXX: 2022-10-01
    qa (012345678902)
        qa-user-1
            AKIAXXXXXXXXXXXXXXXX: None
    ```
  
- `./iam_keys_audit.sh -p dev,qa --pretty`

  ![key_audit_pretty.png](img/key_audit_pretty.png)

- `./iam_keys_audit.sh -p dev,qa --pretty --ignore-inactive --disable-status-flags`

  ![key_audit_pretty_filtered.png](img/key_audit_pretty_filtered.png)
