#!/bin/bash

# List networks in ZT

source "functions.bash"
tmpfile='tmp/file.tmp'

rm -f ${tmpfile}
echo "   Network___Description___RangeStart___RangeEnd" > ${tmpfile}

for i in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}" | egrep -o '[a-f0-9]{16}'
); do

        desc=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/$i" |jq '.name' | sed 's/"//g')
	ipAssign=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/$i" |jq -r '.ipAssignmentPools[].ipRangeStart,.ipAssignmentPools[].ipRangeEnd' | paste -sd, -  | sed 's/,/___/g')

	echo "   ${i}___${desc}___${ipAssign}" >> ${tmpfile}

done
# Dynamic menu from:
# https://gist.github.com/nhoag/c202b3dd346668d6d8c1
cat ${tmpfile} | column -t -s "___" |head -1
ENTITIES=$(cat ${tmpfile} | grep -v "   Network___" | column -t -s "___")
SELECTION=1

while read -r line; do
	echo "$SELECTION) $line"
	((SELECTION++))
done <<< "$ENTITIES"

 ((SELECTION--))

 echo
 printf 'Hit Enter when done: '
read -r opt
if [[ $(seq 1 $SELECTION) =~ $opt ]]; then

# Get the selection value
net=$(sed -n "${opt}p" <<< "$ENTITIES")
fi

exit 0
