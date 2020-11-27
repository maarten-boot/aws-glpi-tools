#! /bin/bash

aws_profiles_get()
{
    cat <<! |
account-prod        aws-prod
account-dev         aws-dev
account-marketplace aws-marketplace
!
    awk '
    /^[ \t]*$/ { next }
    /^[ \t]*#/ { next }
    /^[ \t]*;/ { next }
    { print $1, $2 }
    '
}

main()
{
    aws_profiles_get
}

main
