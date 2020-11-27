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

glpi_get_host()
{
    local name="$1"

    echo "
select
    name
from
    glpi_computers
where
    name = '$name'
and
    is_deleted = 0
"
}

glpi_user_host_old()
{
    echo "
select
    name, date_mod
from
    glpi_users
where
    date_mod < '$DATETIME'
and
    name like 'ec2:%'
and
    is_deleted = 0
"
}

glpi_insert_host()
{
    local name="$1"
    local comment="$2"
    local inst_id="$3"
    local key="$4"


    local sql="
insert into
    glpi_computers
set
    date_creation   = '$DATETIME',
    date_mod        = '$DATETIME',

    name            = '$name',
    comment         = '$comment' ,
    otherserial     = '$inst_id',
    contact         = 'key: $key'
"

    echo "$sql"
}

glpi_update_host()
{
    local name="$1"
    local comment="$2"
    local inst_id="$3"
    local key="$4"

    local sql="
update
    glpi_computers
set
    date_mod    = '$DATETIME',

    name        = '$name',
    comment     = '$comment' ,
    otherserial = '$inst_id',
    contact     = 'key: $key'
where
    name = '$name'
and
    is_deleted = 0
    "

    echo "$sql"
}

# //////////////////////////////////
# //////////////////////////////////

get_regions_all()
{
    local profile="$1"

    aws ec2 describe-regions \
        --profile "$profile" \
        --output text |
    awk '{ print $NF }'
}

get_hosts_profile_region()
{
    local profile="$1"
    local region="$2"

    aws ec2 describe-instances \
        --profile "$profile" \
        --region "$region" |
    tee "$TMPDIR/aws-hosts-$profile-$region.json" |
    filter_hosts "$profile" |
    tee "$TMPDIR/aws-hosts-$profile-$region.csv"
}

filter_hosts()
{
    local profile="$1"

    jq -r '
        .Reservations[].Instances[] |
        [
            .InstanceId,
            .InstanceType,
            .PrivateDnsName,
            .PublicDnsName,
            .State.Name,
            .KeyName,
            .Placement.AvailabilityZone,
            (
                .Tags | (
                    map( .Key + ": " + .Value ) |
                    sort |
                    join(";;")
                ) // "<null>"
            )
        ] |
        @csv
    ' |
    awk -v p="$profile" '
    {
        sub(/""/,"\"<null>\"")

        sub(/^"/,"")
        gsub(/","/,"\t");
        sub(/"$/,"")

        print $0 "\t" p
    }'
}

cleanup_name()
{
    local name="$1"

    echo $name |
    tr '"' ' ' |
    awk '{
        sub(/\.internal.*/,"");
        sub(/\.ec2$/,"");
        sub(/\.compute$/,"");

        if( $1 ~ /ec2:/ ) {
            print $1
        } else {
            print "ec2:" $1
        }
    }'
}

do_glpi_ins_upd()
{
    local name="$1"
    local label="$2"

    local comment="$3"
    local instance="$4"
    local key="$5"

    local name2="$name $label"

    glpi_get_host "$name2" | glpi-sql-do.sh | grep -q "$name2" || {
        glpi_insert_host "$name2" "$comment" "$instance" "$key" | glpi-sql-do.sh
        echo "inserted host: $name2"
        return
    }

    glpi_update_host "$name2" "$comment" "$instance" "$key" | glpi-sql-do.sh
    [ "$WITH_UPDATE" != "0" ] && {
        echo "updated: $name2"
    }
}

# //////////////////////////////////
# //////////////////////////////////

do_hosts_all_accounts_all_regions()
{
    aws-profiles-get.sh |
    while read AWS_PROFILE LABEL
    do
        get_regions_all "$AWS_PROFILE" |
        while read region
        do
            get_hosts_profile_region "$AWS_PROFILE" "$region" |
            while IFS=$'\t' read -r instance type name external state key reg  tags acc
            do
                name=$( cleanup_name "$name" )

                local ttt=$( echo "$tags" | awk '{ gsub(/;;/,"\n"); print }' )
                local comment="AWS:$acc:$region:$reg
id= $instance
type= $type
internal= $name
external= $external
state= $state
key= $key
av_zone= $reg
region= $region
account= $LABEL

TAGS
$ttt
"
                do_glpi_ins_upd "$name" "$LABEL" "$comment" "$instance" "$key"

            done
        done
    done
}

main()
{
    do_hosts_all_accounts_all_regions

    glpi_user_host_old | glpi-sql-do.sh |
    awk '$1 == "name" { next } { print }' |
    while read line
    do
        echo "Host no longer in aws: $line"
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

