#!/bin/bash

# Script to manage the networks for self-hosted ZT Controllers

# Check if user ID is 0
if [[ $EUID -ne 0 ]]; then

	echo "################################"
	echo "This script must be run as root" 
	echo "################################"
	exit 1

fi

# Temp File
tmpfile='/tmp/znetwork.tmp'

function  mainMenu() {

	function allNets() {
	# Get all Networks
	for i in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/" | egrep -o '[a-f0-9]{16}'
	); do

		# Get the network's name
	        desc=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/$i" |jq '.name' | sed 's/"//g')

			#if [[ "${desc}" != "null" ]]; then

		                echo "$i   $desc" >> ${tmpfile}

			#fi

	done

	# Dynamic menu from:
	# https://gist.github.com/nhoag/c202b3dd346668d6d8c1
	ENTITIES=$(cat ${tmpfile})
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

		mainMenu
	fi
	if [[ `seq 1 $SELECTION` =~ $opt ]]; then
	
		# Get the selection value
		net=$(sed -n "${opt}p" <<< "$ENTITIES")

	fi

}
clear

# Remove temp file
if [[ -f ${tmpfile} ]]; then

	rm -f ${tmpfile}

fi
	echo "################################"
	echo "  ZeroTier Manager Controller   "
	echo "################################"
	echo ""

echo "1. Create a new ZT Network on this controller"
echo "2. Delete a ZT Network on this controller"
echo "3. Peer Management"
echo "4. Edit Flow Rules for Network"
echo "5. List all networks."
echo "[E]. Exit"
read -p  "Please select a numeric value: " todo

case "${todo}" in

	1)
		netManage
	;;

	2)

	echo "Please wait..."

	if [[ -f ${tmpfile} ]]; then

		rm -f ${tmpfile}

	fi

	allNets

	delnet=$(echo "${net}" | awk ' { print $1 } ')
	read -p "Are you sure you want to delete the network => ${net} [y|N]:" todelete

	if [[ "${todelete}" == "y" ||  "${todelete}" == "yes" ]]; then

		# Delete the network
		curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -X DELETE "http://localhost:9993/cotroller/network/${delnet}"

		# Query to see if it was deleted
		thenDelete=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -X DELETE "http://localhost:9993/cotroller/network/${delnet}")
		clear

		if [[ "${thenDelete}" == "{}" ]]; then

			echo ""
			echo "The network => ${net} was deleted...Please Wait..."
			sleep 2
		else

			echo ""
			echo "The network => ${net} was not deleted...Please Wait..."
			sleep 2
		fi

	fi

	;;

	3)
		bash peer.bash

	;;

	4) # Edit rules file

		cd flowRules

		# List networks
		allNets

		# The network the user selected
		editNet=$(echo "${net}" | awk ' { print $1 } ')

		# If the rules file exists
		if [[ -f  ${editNet}.config ]]; then

			# Edit it
			nano ${editNet}.config
		else

			# If not, copy the config
			cp default.flows  ${editNet}.config
			nano ${editNet}.config

		fi

		clear
		read -p "Would you like to commit the changes? Y|n: " goflow

		if [[ "${goflow}" =~ ^(y|Y)$ ]]; then

			bash ztrules.bash ${editNet}.config

			echo "Rules committed.  Be sure to test...please wait..."
			sleep 3
		else

			echo "Changes will not be committed...Please Wait..."
			sleep 2

			mainMenu

		fi

	;;

	5) bash listnets.bash


	;;

	e|E)

		echo "Exiting..."
		exit 0

	;;

	*)


		echo "Invalid option...Please wait..."
		sleep 2

	;;


esac

mainMenu

}

function netManage() {

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

		echo "Invalid IP...please wait."
		sleep 2
		user_ip

	else

		ipnet=${theip}


	fi

fi

}

genIP

	function get_mask() {
	
		# Get a netmask
		read -p "Provide the netmask or cidr notation.  If you are unsure, just hit Enter and it will use /24 (if you don't plan to have more than 254 peers on this network): " themask

		# Remove slash if provided.
		themask=$(echo ${themask} | sed 's/\///g')

		if [[ "$(ipcalc ${1}/${themask})" =~ "INVALID MASK" ]]; then

			echo "Invalid mask...please wait."
			sleep 2
			get_mask


		else 

			# ipcalc does all the work.
			get_net=$(ipcalc ${ipnet}${themask})

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

			# Function to check if json object created properly
			function chk_jq() {

			if [[ $? -eq 0 ]]; then

				echo "Error with jq Query IP Assignment...please wait..."
				echo "Please try again."
				sleep 2
				get_mask


			else

				get_mask

			fi
			}

			if [[ "${netok}" =~ ^(y|Y)$ ]] ; then

				cnet=$(echo ${2} | sed 's/\"//g')

				# Construct IP Assignment for ZT
				json=$(jq -n --arg Start "${min}" --arg End "${max}" '{ ipAssignmentPools:[{ipRangeStart: $Start,ipRangeEnd: $End}] }')

				assignIP=$(curl -s -X POST \
 					-H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" \
 					-d "$json" "http://localhost:9993/controller/network/${cnet}" | jq -r '(.ipAssignmentPools[0].ipRangeEnd)')

				route='""'

				# Construct Route for LAN
				 json=$(jq -n --arg target "${network}"  --arg route "${route}" '{ routes:[{target: $target, via:$route}] }')
				# Set LAN ROUTE
				lanRoute=$(curl -s -X POST \
 					-H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" \
                                        -d "$json" "http://localhost:9993/controller/network/${cnet}" | jq -r '(.routes[0].target)')

				# Turn on DHCP for auto assigning IPs
				json=$(jq -n --arg dhcpOn "true" '{ v4AssignMode: { zt : $dhcpOn } }')

				 # Set LAN ROUTE
                                autoIP=$(curl -s -X POST \
                                        -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" \
					-d "$json" "http://localhost:9993/controller/network/${cnet}" |jq -r '(.v4AssignMode.zt)')


				# Check if network returns the same settings provided.
				if [[ ("${assignIP}" == "${max}" && "${lanRoute}" == "${network}" && "${autoIP}" == "true") ]]; then


					echo "The network settings were enabled.  Peers can now join and will be assigned an IP address. Press Enter."
					read -p ""
					mainMenu


				else

					echo "Error adding the network settings...Please wait..."
					sleep 2
					mainMenu

				fi 


			else


				genIP
			fi
		
		fi

	}

  read -p "Please enter a description for the network: " netDesc

  	# Create the network
	CONTROLLER_ID=$(zerotier-cli info | cut -d' ' -f 3)
	newNet=$(curl -s -X POST \
	-H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" \
	-d '{"name": "'"${netDesc}"'"}' \
	"http://localhost:9993/controller/network/${CONTROLLER_ID}______" | jq '(.nwid)')

	if [[ "${newNet}" =~ ^\"[0-9a-f]{16}\" ]]; then

		echo "Network created. ID: ${newNet}...Please wait..."
		sleep 1

		get_mask ${ipnet} ${newNet}

	else

		echo "Network was not created...Please wait..."
		sleep 3

	fi
}

mainMenu
