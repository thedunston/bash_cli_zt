#!/bin/bash

# Script to manage the networks for self-hosted ZT Controllers

source "functions.bash"

# Check if user ID is 0
if [[ $EUID -ne 0 ]]; then

	echo "################################"
	echo "This script must be run as root" 
	echo "################################"
	exit 1

fi

# Temp File
tmpfile='/tmp/znetwork.tmp'

function allDone() {

	read -p "${1}. Press Enter to finish"
	${2}
}

# Check that the number is valid entered
function checkNum() {

	if ! [[ ${1} =~ ^[0-9]$ ]]; then

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

function  mainMenu() {

	# Remove temp file
	if [[ -f ${tmpfile} ]]; then

		rm -f ${tmpfile}

	fi

	clear
	echo "################################"
	echo "  ZeroTier Manager Controller   "
	echo "################################"
	echo ""

	echo "1. Create a new ZT Network on this controller"
	echo "2. Delete a ZT Network on this controller"
	echo "3. Peer Management"
	echo "4. Edit Flow Rules for Network"
	echo "5. List all networks"
	echo "6. Manage Routes"
	echo "7. Update Network Description"
	echo "8. Update Network IP Assignment"
	echo "[A]dvanced Options (edit /var/lib/zerotier/local.conf"
	echo "[E]xit"
	read -p  "Please select a numeric value: " todo

	case "${todo}" in

		1)

			clear
			createNet
		;;

		2)

		clear

		echo "Please wait..."

		if [[ -f ${tmpfile} ]]; then

			rm -f ${tmpfile}

		fi

		allNets

		delnet=$(echo "${net}" | awk ' { print $1 } ')
		read -p "Are you sure you want to delete the network => ${net} [y|N]:" todelete

		if [[ "${todelete}" == "y" ||  "${todelete}" == "yes" ]]; then

			# Delete the network
			curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -X DELETE "${ztAddress}/${delnet}"

			# Query to see if it was deleted
			thenDelete=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -X DELETE "${ztAddress}/${delnet}")

			if [[ "${thenDelete}" == "{}" ]]; then

				allDone "The network => ${net} was deleted" "mainMenu"

			else

				allDone "The network => ${net} was not deleted" "mainMenu"
				
			fi

		fi

		;;

		3)

			clear
			bash peer.bash

		;;

		4) # Edit rules file

			clear
			cd flowRules

			# List networks
			allNets "mainMenu:flows"

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

			function cleanup() {

				rm -f ztconfig-${editNet}.tmp
				rm -f ${editNet}.config.json

			}
			clear
			read -p "Would you like to commit the changes? Y|n: " goflow

			if [[ "${goflow}" =~ ^(y|Y)$ ]]; then

				bash ztrules.bash ${editNet}.config
				cleanup

				cd ..
				echo ""
				read -p "Rules committed.  Be sure to test. Press Enter when done."
				mainMenu
			else

				echo ""
				read -p "Changes will not be committed. Press enter when done."

				cd ..
				mainMenu

			fi

		;;

		5)

			clear
			bash listnets.bash


		;;


		6)

			clear

			bash ztroutes.bash

		;;
		7)  # Update network description

			clear
			updateDesc

		;;

		8) # Update Network IP Assignment

			clear

			updateNetIP

		;;

		a|A)

			clear
			bash advancedZT.bash

		;;
		e|E)

			echo "Exiting..."
			exit 0

		;;

		*)


			echo "Invalid option."
			read -p "Press ENTER when done."

		;;


	esac

	mainMenu

}

mainMenu
