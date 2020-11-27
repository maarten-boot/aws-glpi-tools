#! /bin/bash

do_sql_glpi()
{
    mysql --defaults-group-suffix=glpi-glpi -b
}

main()
{
    do_sql_glpi
}

main
