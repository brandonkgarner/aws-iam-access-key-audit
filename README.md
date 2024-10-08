# aws-iam-access-key-audit

This script will find all IAM users across multiple AWS accounts and report their associated access keys with last usage dates. It will compare the last usage to a date and signify it hasn't been used in some time. 

AWS profiles should already be configured on the machine.

**Default is "Has been used in the current year"**.

## Usage

### Options
    -p, --profiles   Comma-separated list of AWS profiles (default: ( default ))"
    -r, --region     AWS region (default: us-east-1)"
    --raw            Disable all formatting"
    --raw-with-old   Disable all formatting except signify old"
    -h, --help       Display this help message"

### Examples
- `./iam_keys_audit.sh -p dev,qa`

    <pre>
    <b><u>dev (012345678901)</u></b>
        dev-user-1
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08
        dev-user-2
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08

    <b><u>qa (012345678902)</u></b>
        qa-user-1
            AKIAXXXXXXXXXXXXXXXX: <span style="color:red">None</span>
    </pre>

- `./iam_keys_audit.sh -p dev,qa --raw-with-old`

    <pre>
    dev (012345678901)
        dev-user-1
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08
        dev-user-2
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08
    qa (012345678902)
        qa-user-1
            AKIAXXXXXXXXXXXXXXXX: None *
    </pre>

- `./iam_keys_audit.sh -p dev,qa --raw`

    <pre>
    dev (012345678901)
        dev-user-1
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08
        dev-user-2
            AKIAXXXXXXXXXXXXXXXX: 2024-10-08
    qa (012345678902)
        qa-user-1
            AKIAXXXXXXXXXXXXXXXX: None
    </pre>