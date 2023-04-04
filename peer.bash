#!/bin/bash

# Script to manage peers
# Oscar's Blog was very helpful in learning to query and edit ZT API
# https://blog.ogarcia.me/zerotier/

source "functions.bash"

if [[ -f "${peerTempFile}" ]]; then

	rm "${peerTempFile}"

fi

# Get all networks
allNets "exit 0"

# Get the selected network
theNet=$(cat 'tmp/ztcurrent.txt')
echo ""
echo "#############   PEER MANAGEMENT #################"
echo "Please wait..."
clear
echo "#########   WHICH PEER NETWORK DO YOU WANT TO MANAGE #######"
echo ""

# Create the network's directory if it 
# doesn't exist and members
if [[ ! -d "networks/${theNet}" ]]; then
	
	mkdir -p "networks/${theNet}"
	
fi

function existingPeerInfo() {

	# Get existing peer information
	exPeerName="$(grep PEERNAME networks/${theNet}/${themem} | cut -d: -f2 )"
	exPeerDesc="$(grep PEERDESC networks/${theNet}/${themem} | cut -d: -f2 )"
	themem_info="ID: ${themem} Name: ${exPeerName} Description: ${exPeerDesc}"

}

function delTemp() {

	# Delete temp file if it exists
	if [[ -f ${tmpPeerFile} ]]; then

		rm -f ${tmpPeerFile}

	fi

}

function selectMem() {

	# Get a list of all the peers
	PEERS=$(cat ${tmpPeerFile} |grep -v Peer | column -t -s " " | sed 's/___/ /g')
	SELECTION=1

	while read -r line; do

		echo "$SELECTION) $line"
		((SELECTION++))
		#echo "[E] Exit"

	done <<< "$PEERS"

	((SELECTION--))

	echo
	printf "Select the number next to the peer to ${1} or "E" to not ${1} Peers: "
	read -r opt

	if [[ ${opt} == "E" ]]; then

		peerManage

	fi

}

function getAllPeers() {

	# Add header to file
	echo "Peer IP Name" > ${tmpPeerFile}

	# Get all the members
	for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "${ztAddress}/${theNet}/member"| egrep -o '[a-f0-9]{10}'); do

		# Check if the peer is authorized
		ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" | jq '.authorized')
		ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" | jq -r '.ipAssignments[]')

		# ...is so then display it.
		if [[ "${ifAuth}" == "true" ]]; then

			existingName=$(grep PEERNAME "networks/${theNet}/${themem}" | cut -d: -f2)

			echo "${themem} ${ifIP} ${existingName}" >> ${tmpPeerFile}

		fi

	done

	# Check to see if there are any peers
	if [[ -f ${tmpPeerFile} || ! -f ${tmpPeerFile} ]]; then 
	
		if [[ ! -s  ${tmpPeerFile} ]]; then
	
			echo "There are no authorized peers."
			read -p "Press ENTER when done."
	
		fi

	fi
}

function peerManage() {
	
	# Create members if they do not exist.
	for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "${ztAddress}/${theNet}/member"| egrep -o '[a-f0-9]{10}'); do
	
		if [[ ! -f "networks/${theNet}/${themem}" ]]; then
	
			touch networks/${theNet}/${themem}
	
		fi
	
	done

	clear

	delTemp

	echo "##################################################"
	echo "Network ID and Name: ${net}"
	echo "##################################################"
	echo "1. List all peers"
	echo "2. List all unauthorized peers"
	echo "3. List only authorized peers"
	echo "4. Deauthorize a peer"
	echo "5. 'Delete' a peer"
	echo "6. Add/Change a peer's name or description"
	echo "7. 'UnDelete' a peer"
	echo "[Z] Back to Network Configuration Main Menu"
	echo "[E] Exit Program"
	read -p " Please select a number value: " todo

	case "${todo}" in

		1) # List all peers
			clear
    	
			# Add header to file
			echo "Peer IP Name" > ${tmpPeerFile}

			for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "${ztAddress}/${theNet}/member"| egrep -o '[a-f0-9]{10}'); do

				# Check if the member is authorized.
				ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" |jq -r '.ipAssignments[]')
				ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" |jq '.authorized')
	
				# If the user is authorized, don't show them
				if [[ ("${ifAuth}" =~ "false" && "${ifIP}" =~ "127.0.0.100") ]]; then
	
					continue

				else
	
					# Get existing peer details
					existingPeerInfo
					
					# Write results to the temp file.
					echo "${themem} ${ifIP} ${exPeerName}" >> ${tmpPeerFile}

				fi
	
			done

			if [[ "$(cat ${tmpPeerFile})" =~ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} ]]; then

				cat ${tmpPeerFile} | column -t -s " " | sed 's/___/ /g'

				read -p "Hit Enter when done."

			else

				echo "There are no members."
				read -p "Press ENTER when done."
				peerManage

			fi

		;;

     		2) # List all unauthorized peers
			clear

			delTemp
	
			# Get all the members
		    	for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "${ztAddress}/${theNet}/member"| egrep -o '[a-f0-9]{10}'); do
	
				# Check if the member is authorized.
				ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" |jq '.ipAssignments[0]')
				ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" |jq '.authorized')
	
				# If the user is authorized, don't show them
				if [[ "${ifIP}" =~ "127.0.0.100" || ("${ifAuth}" == "true") ]]; then
	
					continue

				else
	
					# Write results to the temp file.
					echo "${themem}" >> ${tmpPeerFile}

				fi
	
			done

				# Authorize a peer
				function authPeers() {
	
					selectMem "Authorize"
	
					# Authorize the member
					if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
					
						# Get the selection value
						thePeer=$(sed -n "${opt}p" <<< "${PEERS}")
						themem=$(echo "${thePeer}" | awk ' { print $1 } ')
	
						authed=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -X POST -d '{"authorized": true}' "${ztAddress}/${theNet}/member/${themem}")
					fi
	
				}
	
				# Check to see if there are any peers
				if [[ -f ${tmpPeerFile} ]]; then

					authPeers

				else 

					echo "There are no unauthorized peers."
					read -p "Press ENTER when done."
	
				fi
	
			;;
			3) # List authorized Peers
				clear
	
				delTemp

				# Add header to file
				echo "Peer IP Name" > ${tmpPeerFile}

				# Get all the members
	    			for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "${ztAddress}/${theNet}/member"| egrep -o '[a-f0-9]{10}'); do

					# Check if the peer is authorized
					ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" | jq '.authorized')
					ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" | jq -r '.ipAssignments[]')

					# ...is so then display it.
					if [[ "${ifAuth}" == "true" ]]; then
				
						# Get existing Peer info details
						existingPeerInfo
				

						echo "${themem} ${ifIP} ${exPeerName}" >> ${tmpPeerFile}

					fi

				done

				# Check to see if there are any peers

				if [[ -f ${tmpPeerFile} || ! -f ${tmpPeerFile} ]]; then 
	
					if [[ ! -s  ${tmpPeerFile} ]]; then
	
						echo "There are no authorized peers."
						read -p "Press ENTER when done."
	
					else
	
						cat ${tmpPeerFile} | column -t -s " " | sed 's/___/ /g'
						echo ""
						read -p "Press ENTER when done."
					fi

				fi

		;;

		4)

			clear

			delTemp

			# Add header to file
			echo "Peer IP Name" > ${tmpPeerFile}

			# Get all the members
		    	for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "${ztAddress}/${theNet}/member"| egrep -o '[a-f0-9]{10}'); do
	
				# Check if the peer is authorized
				ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" | jq '.authorized')
				ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" | jq -r '.ipAssignments[]')

				# ...is so then display it.
				if [[ "${ifAuth}" == "true" ]]; then

					# Get existing Peer Info
					existingPeerInfo

					echo "${themem} ${ifIP} ${exPeerName}" >> ${tmpPeerFile}

				fi
	
			done

			# unAuthorize a peer
			function unAuthPeers() {


				# Get a list of all the peers
				selectMem "Deauthorize"
				
				# deauthorize the member
				if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
				
					# Get the selection value
					thePeer=$(sed -n "${opt}p" <<< "${PEERS}")
					themem=$(echo "${thePeer}" | awk ' { print $1 } ')

					unAuthed=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -X POST -d '{"authorized": false}' "${ztAddress}/${theNet}/member/${themem}" | jq -r '.authorized')

					if [[ "${unAuthed}" == "false" ]]; then

						read -p "The peer: ${themem} was set to unauthorized. Hit Enter to continue."
						peerManage

					else

						read -p "The peer: ${themem} was NOT set to unauthorized. Hit Enter to continue."
						unAuthPeers
						
					fi

				fi

			}

			# Check to see if there are any peers
			if [[ -f ${tmpPeerFile} ]]; then

				unAuthPeers

			else 

				echo "There are no unauthorized peers."
				read -p "Press ENTER when done."

			fi

		;;

		5) # Delete a member

			clear

			delTemp
			
			# Get all the members
	    		for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "${ztAddress}/${theNet}/member"| egrep -o '[a-f0-9]{10}'); do

				# Check if the peer is authorized
				ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" |jq '.ipAssignments[]')

				if [[ "${ifIP}" =~ "127.0.0.100" ]]; then

					continue

				else
	
					# Get existing Peer Info
					existingPeerInfo	

					echo "${themem} ${exPeerName}" >> ${tmpPeerFile}

				fi

			done
			# deAuthorize a peer
			function deAuthPeers() {

				selectMem "Remove"

				# Authorize the member
				if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
				
					# Get the selection value
					thePeer=$(sed -n "${opt}p" <<< "${PEERS}")
					
					# Get the member ID	
					themem=$(echo "${thePeer}" | awk ' { print $1 } ')

					delPeer=$(curl -s -X POST -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -d '{"authorized": false}' "${ztAddress}/${theNet}/member/${themem}" | jq '.authorized')

				fi

				# Peers can't be removed from the network so the IP is changed to 127.0.0.100 as a flag that it should not appear when listing members.
				reIP=$(curl -X POST -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  -d '{"ipAssignments":["127.0.0.100"]}' "${ztAddress}/${theNet}/member/${themem}" | jq '(.ipAssignments[] == "127.0.0.100")')

	echo "DELPEER: ${delPeer}"
	echo "REIP: ${reip}"
				if [[ ("${delPeer}" == "false" && "${reIP}" == "true" ) ]]; then

					# Delete Peer information
					rm -f networks/${theNet}/${themem}
					echo "Peer: ${themem} 'removed'"

				else

					echo "Peer: ${themem} was not removed."
					echo "Authorized => ${delPeer}"
					echo "IP => ${reIP}"
					read -p "Press ENTER when done."
					peerManage

				fi
			}

			# Check to see if there are any peers
			if [[ -f ${tmpPeerFile} ]]; then

				deAuthPeers

			else

				echo "There are no peers to delete."
				read -p "Press ENTER when done."

	
			fi

			;;

		6)

			clear
			# Get all peers
			getAllPeers

			# Bring up Edit menu
			selectMem "Edit"
			
			# Authorize the member
			if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
		
				# Get the selection value
				thePeer=$(sed -n "${opt}p" <<< "${PEERS}")

				# Get the member ID
				themem=$(echo "${thePeer}" | awk ' { print $1 } ')

				existingPeerInfo

				# Existing Information
				if [[ ${exPeerName} != "" ]]; then

					echo "Existing Name: ${exPeerName}"

				else

					exPeerName="empty"

				fi

				if [[ ${exPeerDesc} != "" ]]; then

					echo "Existing Description: ${exPeerDesc}"

				else

					exPeerDesc="empty"

				fi

				echo "${themem_info}"
				# Prompt for the user
				read -p "Enter the peer name (leave blank for no changes): " peerName
				read -p "Enter the Peer Description (leave blank for no changes): " peerDesc

				# If no changes then go back to Peer Manage page.
				if [[ "${peerName}" == "" && "${peerDesc}" == "" ]]; then

					peerManage
				fi
				echo "New Name: ${peerName}"
				echo "New Desc: ${peerDesc}"
				read -p "To add the new information above, hit Enter or E to not change." toEdit

				# Check if user wants to exit
				if [[ "${toEdit}" =~ ^(e|E)$ ]]; then

					peerManage

				fi

				# Add Peer information if change is detected
				if [[ "$(grep PEERNAME networks/${theNet}/$themem |cut -d: -f2)" != "${exPeerName}" ]]; then

					replaceSpace="$(echo ${peerName} | sed 's/ /___/g')"
					echo "PEERNAME:${replaceSpace}" > "networks/${theNet}/$themem"

				fi
				if [[ "$(grep PEERDESC networks/${theNet}/$themem |cut -d: -f2)" != "${exPeerDesc}" ]]; then
					echo "PEERDESC:${peerDesc}" >> "networks/${theNet}/$themem"

				fi
				if [[ $? -eq 0 ]]; then

					read -p "Peer Information added. Press Enter to continue." readEnter

					peerManage

				fi

			fi

		;;

		7)

			clear

			delTemp
			
			# Get all the members
	    		for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "${ztAddress}/${theNet}/member"| egrep -o '[a-f0-9]{10}'); do

				# Check if the peer is authorized
				ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "${ztAddress}/${theNet}/member/${themem}" |jq '.ipAssignments[]')

				if [[ "${ifIP}" != "\"127.0.0.100\"" ]]; then

					continue

				else
	
					# Get existing Peer Info
					existingPeerInfo	

					echo "${themem} ${exPeerName}" >> ${tmpPeerFile}

				fi

			done

			# deAuthorize a peer
			function deAuthPeers() {

				selectMem "Undelete"

				# Authorize the member
				if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
				
					# Get the selection value
					thePeer=$(sed -n "${opt}p" <<< "${PEERS}")
					
					# Get the member ID	
					themem=$(echo "${thePeer}" | awk ' { print $1 } ')

					delPeer=$(curl -s -X POST -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -d '{"authorized": false}' "${ztAddress}/${theNet}/member/${themem}" | jq '.authorized')

				fi

				# Unset the 127.0.0.100 IP.
				reIP=$(curl -X POST -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  -d '{"ipAssignments":[]}' "${ztAddress}/${theNet}/member/${themem}" | jq '(.ipAssignments[] == "")')

				# Should return nothing if it was successfully undeleted.
				if [[ "${reIP}" == "" ]]; then

					# UnDelete Peer information
					touch networks/${theNet}/${themem}
					echo "Peer: ${themem} 'was undeleted'"
					read -p "Press ENTER when done."

				else

					echo "Peer: ${themem} was not undeleted."
					read -p "Press ENTER when done."
					peerManage

				fi
			}

			# Check to see if there are any peers
			if [[ -f ${tmpPeerFile} ]]; then

				deAuthPeers

			else

				echo "There are no peers to undelete."
				read -p "Press ENTER when done."

	
			fi


		;;
		z|Z) # Back to Main configuration

			bash ztnetworks.bash
			exit 0
		;;	

		e|E)

			exit 0

		;;
		*)

			echo "Invalid Option!"
			read -p "Press ENTER when done."
			peerManage

		;;

    esac
peerManage
     echo ""

}

#fi
peerManage
