#! /bin/bash
# //////////////////////////////////
# //////////////////////////////////

THIS=$( basename "$0" ".sh" )
DATETIME=$( date "+%Y-%m-%d %H:%M:%S" )

# //////////////////////////////////
# //////////////////////////////////

WITH_EMAIL="1"
WITH_UPDATE="0"

MAILTO="maarten@reversinglabs.com"
TMPDIR="./tmp"

# //////////////////////////////////
# //////////////////////////////////

LOGFILE="/tmp/$THIS.log"
PATH=.:$PATH export PATH

# //////////////////////////////////
# //////////////////////////////////

# create cli user and access key

glpi_user_get()
{
    local name="$1"

    echo "
select
    name
from
    glpi_users
where
    name = '$name'
and
    is_deleted = 0
"
}

glpi_user_get_old()
{
    echo "
select
    name, comment, date_mod
from
    glpi_users
where
    date_mod < '$DATETIME'
and
    comment like '%arn:aws:iam:%'
and
    is_deleted = 0
"
}

glpi_user_ins()
{
    # this does not work, switched to glpi api mode, for insert user
    local name="$1"
    local comment="$2"

    echo "
insert into
    glpi_users
set
    name = '$name',
    comment = '$comment',
    date_creation = '$DATETIME',
    date_mod = '$DATETIME'
"
}

glpi_user_upd()
{
    local name="$1"
    local comment="$2"

    echo "
update
   glpi_users
set
    comment = '$comment',
    date_mod = '$DATETIME'
where
    name = '$name'
and
    is_deleted = 0
"
}

# //////////////////////////////////
# //////////////////////////////////

get_access_keys()
{
    local profile="$1"
    local user="$2"

    aws iam list-access-keys \
        --profile "$profile"  \
        --user-name "$user" |
    jq -r '.AccessKeyMetadata[]' |
    grep "$user"
}

create_access_key()
{
    local profile="$1"
    local user="$2"

    aws iam create-access-key \
        --profile "$profile"  \
        --user-name "$user" |
    tee "aws-access-key-$profile-$user"-$( date +%Y%m%d-%H%M%S ).json
}

# //////////////////////////////////
# //////////////////////////////////

get_user()
{
    local profile="$1"
    local user="$2"

    aws iam get-user \
        --profile "$profile"  \
        --user-name "$user" |
    jq -r '.User.Arn' |
    grep "$user"
}

create_user()
{
    return

    local profile="$1"
    local user="$2"

    aws iam create-user \
        --profile "$profile"  \
        --user-name "$user" |
    tee "aws-user-$profile-$user".json
}

list_users()
{
    local profile="$1"

    aws iam list-users \
        --profile "$profile" |
    jq -r '.Users[] | [ .UserName , .Arn ] | @csv' |
    tr '",' '  '
}

# //////////////////////////////////
# //////////////////////////////////

get_group()
{
    local profile="$1"
    local group="$2"

    aws iam get-group \
        --profile "$profile"  \
        --group-name "$group" |
    grep "$group"
}

list_groups()
{
    local profile="$1"

    aws iam list-groups \
        --profile "$profile" |
    jq -r '.'
}

list_attached_group_policies()
{
    local profile="$1"
    local group="$2"

    aws iam list-attached-group-policies \
        --profile "$profile"  \
        --group-name "$group" |
    jq -r '.'
}

list_groups_for_user()
{
    local profile="$1"
    local user="$2"

    aws iam list-groups-for-user \
        --profile "$profile"  \
        --user-name "$user" |
    jq -r '.'
}

list_attached_user_policies()
{
    local profile="$1"
    local user="$2"

    aws iam list-attached-user-policies \
        --profile "$profile"  \
        --user-name "$user" |
    jq -r '.'
}

list_user_policies()
{
    local profile="$1"
    local user="$2"

    aws iam list-user-policies \
        --profile "$profile"  \
        --user-name "$user" |
    jq -r '.'
}

# //////////////////////////////////
# //////////////////////////////////

add_new_user_with_ak()
{
    local profile="$1"
    local user="$2"

    get_user "$profile" "$user" || {
        create_user "$profile" "$user"
    }

    get_access_keys "$profile" "$user" || {
        create_access_key "$profile" "$user"
    }
}

do_users()
{
    get_profiles |
    while read AWS_PROFILE
    do
        add_new_user_with_ak "$AWS_PROFILE" "$USER_NAME"
    done
}

do_groups()
{
    get_profiles |
    while read AWS_PROFILE
    do
        list_groups "$AWS_PROFILE"
    done
}

do_user_actions()
{
    local profile="$1"
    local user="$2"

    list_groups_for_user "$profile" "$user" |
    jq -r '.Groups[].GroupName' |
    while read group
    do
        echo "ug::$profile:$user:$group"

        list_attached_group_policies "$profile" "$group" |
        jq -r '.AttachedPolicies[].PolicyName // empty' |
        awk -vg=$group '{ print "\t" $1, "group", g }'
    done

    (
        list_attached_user_policies "$profile" "$user" |
            jq -r '.AttachedPolicies[].PolicyName // empty' |
            awk -vu=$user '{ print "\t" $1, "user", u }'

        list_user_policies "$profile" "$user" |
            jq -r '.AttachedPolicies[].PolicyName // empty' |
            awk '{ print "\t", $1, "Inline-user" }'
    ) |
    sort -u
}

list_users_and_policies()
{
    aws-profiles-get.sh |
    while read AWS_PROFILE LABEL
    do
        list_users "$AWS_PROFILE" |
        while read user arn
        do
            echo "$AWS_PROFILE $LABEL $user $arn"
        done
    done
}

# //////////////////////////////////
# //////////////////////////////////

main()
{
    list_users_and_policies |
    while read acc label user arn
    do
        local u="$user $label"

        glpi_user_get "$u" | glpi-sql-do.sh | grep -q "$u" || {
            # insert a user with mysql does not work, you cannot use the user in a dropdown, switched to glpi api mode
            # glpi_user_ins "$u" "$arn" | glpi-sql-do.sh
            # echo "new user in aws; INSERT in glpi: $u ; $arn"

            php glpiApiAddUser.php --name "$u" --comment "$arn"
            continue
        }

        # update
        glpi_user_upd "$u" "$arn" | glpi-sql-do.sh

        [ "$WITH_UPDATE" != "0" ] &&  {
            echo "UPD: $u ; $arn"
        }
    done

    glpi_user_get_old | glpi-sql-do.sh |
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
