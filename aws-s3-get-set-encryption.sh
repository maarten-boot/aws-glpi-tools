#! /bin/bash

THIS=$( basename "$0" ".sh" )
DATETIME=$( date "+%Y-%m-%d %H:%M:%S" )

# //////////////////////////////////
# //////////////////////////////////

WITH_EMAIL="1"
WITH_UPDATE="0"

MAILTO="aws-glpi-reports@somedomain.faraway"

TMPDIR="./tmp"
[ ! -d "$TMPDIR" ] && {
    mkdir "$TMPDIR"
}

# //////////////////////////////////
# //////////////////////////////////

LOGFILE="/tmp/$THIS.log"
PATH=.:$PATH export PATH

# //////////////////////////////////
# //////////////////////////////////


s3_get_all_bucket_names() {

	local profile="$1"

	aws s3api list-buckets \
		--profile "$profile" \
		--query "Buckets[].Name" |
        jq -r '.[]'
}

### ## Get

s3_get_bucket_encryption() {

	local profile="$1"
	local Bucket="$2"

	aws s3api get-bucket-encryption \
		--profile "$profile" \
		--bucket "$Bucket" |
	jq -r '
        .ServerSideEncryptionConfiguration.Rules[] |
        .ApplyServerSideEncryptionByDefault
    '
}

### ## Put

s3_put_bucket_encryption_default() {

	locale profile="$1"
	local Bucket="$2"

	local Rules='{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

	aws s3api put-bucket-encryption \
		--profile "$profile" \
		--bucket "$Bucket" \
		--server-side-encryption-configuration "$Rules" |
	jq -r '.'
}

main() {
	aws-profiles-get.sh |
	while read AWS_PROFILE LABEL
	do
		local profile="$AWS_PROFILE"

		s3_get_all_bucket_names "$profile" |
		while read name
		do
			s3_get_bucket_encryption "$profile" "$name" | grep -q ':' || {
                echo "## $name has no default encryption"
                s3_put_bucket_encryption_default "$profile" "$name"
            }
		done
	done
}

main 2>/tmp/"$THIS.2" |
tee "$LOGFILE"

[ "$WITH_EMAIL" = "1" ] && {
    [ -s "$LOGFILE" ] && {
        cat "$LOGFILE" |
        mailx -s "$LOGFILE" $MAILTO

        exit 0
    }
}
