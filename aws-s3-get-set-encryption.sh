#! /bin/bash

get_profiles()
{
	cat <<! |
	account-prod 		aws-prod
	account-dev 		aws-dev
	account-marketplace 	aws-marketplace
!
	awk '
	/^[ \t]*$/ { next }
	/^[ \t]*#/ { next }
	/^[ \t]*;/ { next }
	{ print $1 }
	'
}


## s3

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
	get_profiles |
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

main 2>/tmp/2 |
tee out
