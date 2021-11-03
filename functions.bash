# Various functions for the program

# ZeroTier network address
ztAddress='http://127.0.0.1:9993/controller/network'

# Token file
ztToken='/var/lib/zerotier-one/authtoken.secret'

# Temp File
tmpfile='tmp/znetwork.tmp'
ztnetFile='tmp/ztcurrent.txt'
peerTempFile='tmp/networks.tmp'

# ZT Directory
ztDir='/var/lib/zerotier-one'

# local.conf file 
localConfig=''${ztDir}'/local.conf'
localConfigTemplate='templates/local.conf.template'
bkLocalConfig='tmp/local.conf.tmp'

# Create temp directory
if  [[ ! -d "tmp" ]]; then

	mkdir tmp

fi

function ip_chk() {

	if [[ ${1} =~ ^(e|E)$ ]]; then

		menu

	fi

	# If set to default then the gateway is null so it will set to the default route.
	if [[ ${1} == "default" ]]; then

		if [[ "$(ipcalc ${1})" =~ "INVALID" ]]; then

			echo "Invalid network/host entered."
		      	# Take the user back to the function.
			${2}

		fi

	fi

}

function ipnet_chk() {

	if [[ ${1} =~ ^(e|E)$ ]]; then

		${2}

	fi

	if [[ "$(ipcalc ${1})" =~ "INVALID" ]]; then

		echo "Invalid network/host entered."
	      	# Take the user back to the function.
		${2}

	fi

}

function allDone() {

	read -p "${1}. Press Enter to finish"
	${2}
}

function del_temp() {

	if [[ -f ${tmpRouteFile} ]]; then

		rm -f ${tmpRouteFile}

	fi

}

# Function to check if json object created properly
function chk_jq() {

	if [[ $? -ne 0 ]]; then

		allDone "Error with jq query creation." ${2}
		
	fi

}

# Test an IP address for validity:
# https://www.linuxjournal.com/content/validating-ip-address-bash-script
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if valid_ip IP_ADDRESS; then echo good; else echo bad; fi
#
function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function get_mask() {

: '

# Ipcalc sample
Address:   192.168.0.0          11000000.10101000.00000 000.00000000
Netmask:   255.255.248.0 = 21   11111111.11111111.11111 000.00000000
Wildcard:  0.0.7.255            00000000.00000000.00000 111.11111111
=>
Network:   192.168.0.0/21       11000000.10101000.00000 000.00000000
HostMin:   192.168.0.1          11000000.10101000.00000 000.00000001
HostMax:   192.168.7.254        11000000.10101000.00000 111.11111110
Broadcast: 192.168.7.255        11000000.10101000.00000 111.11111111
Hosts/Net: 2046                  Class C, Private Internet

  echo $((RANDOM%192 + 192)).$((RANDOM%256)).$((RANDOM%256)).$((RANDOM%256))
  560  echo ${P[RANDOM%3]}
 echo $((RANDOM%254))

'

# ipcalc 192.168.0.0/21 -n


	if ! [[ "${autogen}" =~ ^(y|Y)$ ]]; then

		# Get a netmask
		read -p "Provide the netmask or cidr notation.  If you are unsure, just hit Enter and it will use /24 (if you don't plan to have more than 254 peers on this network): " themask

	else

		themask="/24"

	fi

	# Remove slash if provided.
	netmask=$(echo ${themask} | sed 's/\///g')

	if [[ "$(ipcalc ${1}/${netmask})" =~ "INVALID MASK" ]]; then

		echo "Invalid mask."
		read -p "Press ENTER when done."
		get_mask

	else 

		# ipcalc does all the work.
		get_net=$(ipcalc ${ipnet}${netmask})

		# Starting IP in DHCP Pool
		min=$(echo ${get_net} | egrep -o "HostMin: [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | cut -d: -f2  | sed 's/[[:space:]]//g' )

		# End IP in DHCP Pool
		max=$(echo ${get_net} | egrep -o "HostMax: [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | cut -d: -f2  | sed 's/[[:space:]]//g' )

		# Network and CIDR notation
		network=$(echo ${get_net} | egrep -o "Network: [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}" | cut -d: -f2 | sed 's/[[:space:]]//g' )
		
		# Verify the settings
		echo "Start IP: $min"
		echo "End IP: $max"
		echo "Network: $network"
		read -p "Are the above settings okay? [Y|n]" netok

		if [[ "${netok}" =~ ^(y|Y)$ ]] ; then

			cnet=$(echo ${2} | sed 's/\"//g')

			# Construct IP Assignment for ZT
			json=$(jq -n --arg Start "${min}" --arg End "${max}" '{ ipAssignmentPools:[{ipRangeStart: $Start,ipRangeEnd: $End}] }')

			assignIP=$(curl -s -X POST \
				-H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" \
				-d "$json" "${ztAddress}/${cnet}" | jq -r '(.ipAssignmentPools[0].ipRangeEnd)')

			route='""'

			# Construct Route for LAN
			json=$(jq -n --arg target "${network}"  --arg route "${route}" '{ routes:[{target: $target, via:$route}] }')

			# Set LAN ROUTE
			lanRoute=$(curl -s -X POST -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -d "$json" "${ztAddress}/${cnet}" | jq -r '(.routes[0].target)')

			# Turn on DHCP for auto assigning IPs
			json=$(jq -n --arg dhcpOn "true" '{ v4AssignMode: { zt : $dhcpOn } }')

			 # Set LAN ROUTE
                        autoIP=$(curl -s -X POST -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -d "$json" "${ztAddress}/${cnet}" |jq -r '(.v4AssignMode.zt)')

			# Check if network returns the same settings provided.
			if [[ ("${assignIP}" == "${max}" && "${lanRoute}" == "${network}" && "${autoIP}" == "true") ]]; then

				allDone "The network settings were enabled.  Peers can now join and will be assigned an IP address." "mainMenu"
			
			else

				allDone "Error adding the network settings" "mainMenu"

			fi 

		else

			mainMenu
		
		fi
			
	fi

}

function genIP() {

	read -p  "Would you like to autogenerate an IP range? [Y|n] or Enter to return to main menu: " autogen

	if [[ "${autogen}" =~ ^(y|Y)$ ]]; then

		# Private ranges for the ZT Network
		a=(10 192.168 172.16)

		# Select one above
		oct1=${a[RANDOM%3]}

		# $((RANDOM%254)) selects a number 0 - 254
		if [[ "${oct1}" == 10 ]]; then
	
			ipnet="10.$((RANDOM%254)).$((RANDOM%254)).1"
	
		elif [[ "${oct1}" == "172.16" ]]; then
	
			ipnet="172.16.$((RANDOM%254)).1"
	
		else

			ipnet="192.168.$((RANDOM%254)).1"

		fi

	elif [[  "${autogen}" == "" ]]; then

		mainMenu

	else 

		# Manual entry for a network
		function user_ip() {

			echo ""
			read -p  "Enter the first usable IP for the network: " theip
	
			if ! [[  "${theip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then

				user_ip
			fi

		}

		user_ip

		if [[ "$(ipcalc ${theip})" =~ "INVALID" ]]; then

			echo "Invalid IP."
			read -p "Press ENTER when done."
			user_ip

		else

			ipnet=${theip}

		fi

	fi

}

function allNets() {

	rm -f ${tmpfile}

	del_temp
	echo "   Network___Description___RangeStart___RangeEnd" > ${tmpfile}

	# Get all Networks
	for i in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/" | egrep -o '[a-f0-9]{16}'); do

		# Get the network's name
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
	
		echo "B) To go back to the main menu"
	((SELECTION--))
	
	echo
	printf 'Select the number next to the network: '
	read -r opt

	if [[ ${opt} =~ ^(b|B)$ ]]; then

		${1}
	fi

	checkNum ${opt}

	if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
	
		# Get the selection value
		net=$(sed -n "${opt}p" <<< "$ENTITIES")

	fi

	# Write selected network to a file
	echo "${net}" | awk ' { print $1 } ' > ${ztnetFile}

}

function currNet(){

	theNet=$(cat ${ztnetFile})

}

# Check that the number is valid entered
function checkNum() {

	if ! [[ ${1} =~ ^[0-9]$ || ${1} =~ ^b|B$ ]]; then

		allDone "A numeric selection is required" "mainMenu"

	fi

}

# Create the network
function createNet() {

	read -p "Please enter a description for the network: " netDesc

	genIP

  	# Create the network
	CONTROLLER_ID=$(zerotier-cli info | cut -d' ' -f 3)
	newNet=$(curl -s -X POST \
	-H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" \
	-d '{"name": "'"${netDesc}"'"}' \
	"${ztAddress}/${CONTROLLER_ID}______" | jq '(.nwid)')

	if [[ "${newNet}" =~ ^\"[0-9a-f]{16}\" ]]; then

		echo "Network created. ID: ${newNet}."
		read -p "Press ENTER when done."

		get_mask ${ipnet} ${newNet}

	else

		allDone "Network was not created" mainMenu

	fi

}


# Updates the network's IP Assignment
function updateNetIP() {

	allNets

	theNet=$(echo "${net}" | awk ' { print $1 } ')
	
	genIP

	if [[ "${ipnet}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then

		get_mask ${ipnet} ${theNet}

	else

		allDone "IP was not created" "mainMenu"

	fi

}

# Update the network's description
function updateDesc() {

	allNets

	theNet=$(echo "${net}" | awk ' { print $1 } ')
	read -p "Please enter the updated description for the network: " netDesc

	json=$(jq -n --arg desc "${netDesc}" '{ name: $desc }')

	chk_jq

  	# Update the network description
	updateNet=$(curl -s -X POST \
	-H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" \
	-d "$json" \
	"${ztAddress}/${theNet}" | jq -r '(.name)')

	if [[ "${updateNet}" == "${netDesc}" ]]; then

		allDone "${updateNet} description has been updated" mainMenu
		
	else

		allDone "${updateNet} description was not updated" mainMenu

	fi

}

# List interfaces
function listIf() { 

	ENTITIES=$(ip addr |egrep '^[0-9]:{1,2}' | cut -d: -f2 | sed 's/ //g')
        SELECTION=1

        while read -r line; do

                echo "$SELECTION) $line"
                ((SELECTION++))

        done <<< "$ENTITIES"

                echo "B) To go back to the main menu"
        ((SELECTION--))

        echo
        printf 'Select the number next to the interface to Block or press B to go Back: '
        read -r opt

        if [[ ${opt} =~ ^(b|B)$ ]]; then

                manageIF
        fi

        checkNum ${opt}

        if [[ $(seq 1 $SELECTION) =~ $opt ]]; then

                # Get the selection value
                intF=$(sed -n "${opt}p" <<< "$ENTITIES")

        fi

}

# List current interfaces
function listLocalConf() { 

	if [[ "${1}" == "interfacePrefixBlacklist" ]]; then

		ENTITIES=$(grep interfacePrefixBlacklist ${localConfig} | egrep -o '\[.*\]' | sed -e 's/\[//g;s/\]//g;s/[",]/ /g' |tr ' ' '\n' |grep '.')
		msgLocalConf='interface'

	elif [[ "${1}" == "allowManagementFrom" ]]; then

		ENTITIES=$(grep allowManagementFrom ${localConfig} | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}')
		msgLocalConf='IP or Netowrk'

	else

		advZT

	fi

        SELECTION=1

        while read -r line; do

                echo "$SELECTION) $line"
                ((SELECTION++))

        done <<< "$ENTITIES"

	echo "B) To go back to the main menu"
        ((SELECTION--))

        echo
        printf 'Select the number next to the '${msgLocalConf}': '
        read -r opt

	# Check if B to go back or numeric
        if [[ ${opt} =~ ^(b|B)$ ]]; then

                advZT
        fi
        if ! [[ ${opt} =~ [0-9] ]]; then

                advZT
        fi

        checkNum ${opt}

        if [[ $(seq 1 $SELECTION) =~ $opt ]]; then

                # Get the selection value
                currSetting=$(sed -n "${opt}p" <<< "$ENTITIES")

        fi

}
