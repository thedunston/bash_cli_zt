#!/bin/bash

# List networks in ZT

rm -f /tmp/file.tmp

for i in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/" | sed -e 's/\[//g' -e 's/"//g' -e 's/,/ /g' -e 's/\]//g'
); do

        desc=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/$i" |jq '.name' | sed 's/"//g')

        echo "$i   $desc" >> /tmp/file.tmp


done
# Dynamic menu from:
# https://gist.github.com/nhoag/c202b3dd346668d6d8c1
ENTITIES=$(cat /tmp/file.tmp)
SELECTION=1

while read -r line; do
	echo "$SELECTION) $line"
	((SELECTION++))
done <<< "$ENTITIES"


 ((SELECTION--))

 echo
 printf 'Hit Enter when done: '
read -r opt
if [[ `seq 1 $SELECTION` =~ $opt ]]; then

# Get the selection value
net=$(sed -n "${opt}p" <<< "$ENTITIES")
fi

exit 0
