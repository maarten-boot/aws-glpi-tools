# aws-tools

read all s3 bucket names, see if encryption is set, if not set it 

# glpi tools

```
read all ( 
    ec2 instances and their tags, 
    iam users, 
    s3 buckets and their tags 
)          
from all aws accounts and all regions and add them to glpi 
detect removed items from aws and inform via mail
```
in glpi-sql-do.sh, to hide the user/pass i use: 

mysql --defaults-group-suffix=glpi-glpi 

use a mysql external file $HOME/.my.cnf

like:
```
[clientglpi-glpi]   # Note: client + host1
user=<your glpi mysql user>
password=<your glpi mysql database user password>
database=<your glpi datbase name>
host=<your glpi mysql host>
````

the host label here is glpi-glpi, any other label would be ok also
