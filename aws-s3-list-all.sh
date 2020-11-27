#! /bin/bash
# //////////////////////////////////
# //////////////////////////////////

THIS=$( basename "$0" ".sh" )
DATETIME=$( date "+%Y-%m-%d %H:%M:%S" )

# //////////////////////////////////
# //////////////////////////////////

WITH_EMAIL="1"
WITH_UPDATE="0"

MAILTO="aws-glpi-reports@somedomain.faraway"
TMPDIR="./tmp"

# //////////////////////////////////
# //////////////////////////////////

LOGFILE="/tmp/$THIS.log"
PATH=.:$PATH export PATH

# //////////////////////////////////
# //////////////////////////////////

get_bucket_glpi()
{
    local name="$1"

    echo "
select
    name
from
    glpi_plugin_databases_databases
where
    name = '$name'
and
    is_deleted = 0
"
}

ins_bucket_glpi()
{
    local name="$1"
    local comment="$2"

    echo "
insert into
    glpi_plugin_databases_databases
set
    name = '$name',
    comment = '$comment',

    date_mod = '$DATETIME'
"
}

upd_bucket_glpi()
{
    local name="$1"
    local comment="$2"

    echo "
update
    glpi_plugin_databases_databases
set
    comment = '$comment',

    date_mod = '$DATETIME'
where
    name = '$name'
and
    is_deleted = 0
"
}

glpi_bucket_get_old()
{
    echo "
select
    name, comment, date_mod
from
    glpi_plugin_databases_databases
where
    date_mod < '$DATETIME'
and
    name like 's3://%'
and
    is_deleted = 0
"
}

# ////////////////////////////////
# ////////////////////////////////

get_bucket_location()
{
    local profile="$1"
    local b_name="$2"

    aws s3api  get-bucket-location \
        --profile $profile \
        --bucket $b_name |
    jq -r '.LocationConstraint // "us-east-1"'
}

list_s3_all()
{
    aws-profiles-get.sh |
    while read AWS_PROFILE LABEL
    do
        aws s3api list-buckets \
            --profile "$AWS_PROFILE" |
        tee "$TMPDIR/aws-s3-$AWS_PROFILE.json" |
        jq -r '.Buckets[].Name' |
        awk -v p=$AWS_PROFILE '{ print $1, p }' |
        while read b p
        do
            local r=$(
                get_bucket_location "$p" "$b"
            )

            local tags=$(
                aws s3api get-bucket-tagging \
                    --profile "$p" \
                    --bucket "$b" |
                tee "$TMPDIR/aws-s3-$p-$b.json" |
                jq -r '(
                    .TagSet | (
                        map( .Key + ": " + .Value ) |
                        sort |
                        join(";;")
                    ) // "<null>"
                )'
            )

            echo "s3://$b account=$LABEL aws-location=$r $tags"
        done
    done
}

# //////////////////////////////////
# //////////////////////////////////
# set -x

main()
{
    list_s3_all |
    while read name acc loc tags
    do
        local ttt=$(
            echo "$tags" |
            awk '{
                gsub(/;;/,"\n");
                print
            }'
        )
        local comment="
$acc
$loc

TAGS
$ttt
"
        get_bucket_glpi "$name" | glpi-sql-do.sh | grep -q "$name" || {
            ins_bucket_glpi "$name" "$comment" | glpi-sql-do.sh

            echo "Insert $name $acc $loc"
            continue
        }

        # update
        upd_bucket_glpi "$name" "$comment" | glpi-sql-do.sh

        [ "$WITH_UPDATE" != "0" ] && {
            echo "Update $name $acc $loc"
        }
    done

    glpi_bucket_get_old  | glpi-sql-do.sh |
    awk '$1 == "name" { next } { print }' |
    while read line
    do
        echo "User no longer in aws: $line"
    done
}

main 2>&1 |
tee "$LOGFILE"

[ "$WITH_EMAIL" = "1" ] && {
    [ -s "$LOGFILE" ] && {
        cat "$LOGFILE" |
        mailx -s "$LOGFILE" $MAILTO

        exit 0
    }
}
