#!/bin/bash

# Script to manage peers
# Oscar's Blog was very helpful in learning to query and edit ZT API
# https://blog.ogarcia.me/zerotier/

rm /tmp/file.tmp

echo ""
echo "#############   PEER MANAGEMENT #################"
echo "Please wait..."
clear
echo "#########   WHICH PEER NETWORK DO YOU WANT TO MANAGE #######"
echo ""
for i in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/" | sed -e 's/\[//g' -e 's/"//g' -e 's/,/ /g' -e 's/\]//g'); do

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
    printf 'Select a number next to the network: '
    read -r opt
    if [[ `seq 1 $SELECTION` =~ $opt ]]; then

	# Get the selection value
     net=$(sed -n "${opt}p" <<< "$ENTITIES")

    # Pop off the network ID
    thenet=$(echo "${net}" | awk ' { print $1 } ')

function peerManage() {

	clear

	tmpPeerFile='/tmp/ztnetwork-peerfile.tmp'

	function delTemp() {

		# Delete temp file if it exists
		if [[ -f ${tmpPeerFile} ]]; then

			rm -f ${tmpPeerFile}

		fi

	}

	delTemp

	echo "1. List all peers"
	echo "2. List all unauthorized peers"
	echo "3. List only authorized peers"
	echo "4. Unauthorize a peer"
	echo "5. 'Delete' a peer"
	echo "[Z] Back to Network Configuration Main Menu"
	echo "[E] Exit Program"
	read -p " Please select a number value: " todo

	case "${todo}" in

		1) # List all peers
			clear
    	
			# Add header to file
			echo "Peer IP" > ${tmpPeerFile}

			for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "http://localhost:9993/controller/network/${thenet}/member"| egrep -o '[a-f0-9]{10}'); do

				# Check if the member is authorized.
				ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${thenet}/member/${themem}" |jq -r '.ipAssignments[]')
				ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${thenet}/member/${themem}" |jq '.authorized')
	
				# If the user is authorized, don't show them
				if [[ ("${ifAuth}" =~ "false" && "${ifIP}" =~ "127.0.0.100") ]]; then
	
					continue

				else
	
					# Write results to the temp file.
					echo "${themem} ${ifIP}" >> ${tmpPeerFile}

				fi
	
			done

			if [[ "$(cat ${tmpPeerFile})" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} ]]; then

				cat ${tmpPeerFile} | column -t -s " "

				read -p "Hit Enter when done."

			else

				echo "There are no members...please wait..."
				sleep 2
				peerManage

			fi

		;;
     		2) # List all unauthorized peers
			clear

			delTemp
	
			# Get all the members
		    	for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "http://localhost:9993/controller/network/${thenet}/member"| egrep -o '[a-f0-9]{10}'); do
	
				# Check if the member is authorized.
				ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${thenet}/member/${themem}" |jq '.ipAssignments[0]')
				ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${thenet}/member/${themem}" |jq '.authorized')
	
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
	
					# Get a list of all the peers
					echo "Peer"
					PEERS=$(cat ${tmpPeerFile})
					SELECTION=1
					
					while read -r line; do
					        echo "$SELECTION) $line"
					        ((SELECTION++))
					done <<< "$PEERS"
					echo "[E] Exit"
					
					((SELECTION--))
					
					echo
					printf 'Select the number next to the peer to authorize or "E" to not authorize Peers: '
					read -r opt
	
					if [[ ${opt} == "E" ]]; then
	
						peerManage
	
					fi
	
					# Authorize the member
					if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
					
						# Get the selection value
						thePeer=$(sed -n "${opt}p" <<< "${PEERS}")
						themem=$(echo "${thePeer}" | awk ' { print $1 } ')
	
						authed=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -X POST -d '{"authorized": true}' "http://localhost:9993/cotroller/network/${thenet}/member/${themem}")
					fi
	
				}
	
				# Check to see if there are any peers
				if [[ -f ${tmpPeerFile} ]]; then

					authPeers

				else 

					echo "There are no unauthorized peers...please wait..."
					sleep 2
	
				fi
	
			;;
			3) # List authorized Peers
				clear
	
				delTemp

				# Add header to file
				echo "Peer IP" > ${tmpPeerFile}

				# Get all the members
	    			for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "http://localhost:9993/controller/network/${thenet}/member"| egrep -o '[a-f0-9]{10}'); do

					# Check if the peer is authorized
					ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${thenet}/member/${themem}" | jq '.authorized')
					ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${thenet}/member/${themem}" | jq -r '.ipAssignments[]')

					# ...is so then display it.
					if [[ "${ifAuth}" == "true" ]]; then

						echo "${themem} ${ifIP}" >> ${tmpPeerFile}

					fi

				done

				# Check to see if there are any peers

				if [[ -f ${tmpPeerFile} || ! -f ${tmpPeerFile} ]]; then 
	
					if [[ ! -s  ${tmpPeerFile} ]]; then
	
						echo "There are no authorized peers...please wait..."
						sleep 2
	
					else
	
						cat ${tmpPeerFile} | column -t -s " "
						rm -f ${tmpPeerFile}
						echo ""
						sleep 2
					fi

				fi

		;;

		4)

			clear
			# Add header to file
			echo "Peer IP" > ${tmpPeerFile}

			# Get all the members
		    	for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "http://localhost:9993/controller/network/${thenet}/member"| egrep -o '[a-f0-9]{10}'); do
	
				# Check if the member is authorized.
				# Ignore 'deleted' members
				ifAuth=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${thenet}/member/${themem}" |jq -r '.authorized','.ipAssignments[]')

				# I was getting at null iteration error so extracting the IP using egrep
				ifIP=$(echo ${ifAuth} | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
	
				# If the user is 'deleted' or authorized, don't show them
				if [[ "${ifAuth}" == "false" ]]; then
	
					continue

				else
				
					# Write results to the temp file.
					echo "${themem} ${ifIP}" >> ${tmpPeerFile}

				fi
	
			done

				# unAuthorize a peer
				function unAuthPeers() {
	
					# Get a list of all the peers
					PEERS=$(cat ${tmpPeerFile} |grep -v '^Peer' | column -t -s " ")
					SELECTION=1
					
					while read -r line; do
					        echo "$SELECTION) $line"
					        ((SELECTION++))
					done <<< "$PEERS"
					echo "[E] Exit"
					
					((SELECTION--))
					
					echo
					printf 'Select the number next to the peer to Unauthorize or "E" to not authorize Peers: '
					read -r opt
	
					if [[ ${opt} == "E" || ${opt} == ""  ]]; then
	
						peerManage
	
					fi
	
					# Unauthorize the member
					if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
					
						# Get the selection value
						thePeer=$(sed -n "${opt}p" <<< "${PEERS}")
						themem=$(echo "${thePeer}" | awk ' { print $1 } ')
	
						unAuthed=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -X POST -d '{"authorized": false}' "http://localhost:9993/cotroller/network/${thenet}/member/${themem}" | jq -r '.authorized')

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


					echo "There are no unauthorized peers...please wait..."
					sleep 2

	
				fi
	

		;;

		5) # Delete a member
			clear

			delTemp
				
			# Get all the members
	    		for themem in $(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" "http://localhost:9993/controller/network/${thenet}/member"| egrep -o '[a-f0-9]{10}'); do

				# Check if the peer is authorized
				ifIP=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${thenet}/member/${themem}" |jq '.ipAssignments[]')

				if [[ "${ifIP}" =~ "127.0.0.100" ]]; then

					continue

				else
	
					echo "${themem}" >> ${tmpPeerFile}

				fi

				done
				# deAuthorize a peer
				function deAuthPeers() {
	
					# Get a list of all the peers
					PEERS=$(cat ${tmpPeerFile})
					SELECTION=1
					
					while read -r line; do
					        echo "$SELECTION) $line"
					        ((SELECTION++))
					echo "[E] Exit"
					done <<< "$PEERS"
					
					((SELECTION--))
					
					echo
					printf 'Select the number next to the peer to REMOVE or "E" to not REMOVE Peers: '
					read -r opt
	
					if [[ ${opt} == "E" ]]; then
	
						peerManage
	
					fi
	
					# Authorize the member
					if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
					
						# Get the selection value
						thePeer=$(sed -n "${opt}p" <<< "${PEERS}")
						
						# Get the member ID	
						themem=$(echo "${thePeer}" | awk ' { print $1 } ')

						delPeer=$(curl -s -X POST -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -d '{"authorized": false}' "http://localhost:9993/controller/network/${thenet}/member/${themem}" | jq '.authorized')
					fi
	
					# Peers can't be removed from the network so the IP is changed to 127.0.0.100 as a flag that it should not appear when listing members.
					reIP=$(curl  -X POST -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  -d '{"ipAssignments":["127.0.0.100"]}' "http://localhost:9993/controller/network/${thenet}/member/${themem}" | jq '(.ipAssignments[] == "127.0.0.100")')

		echo "DELPEER: ${delPeer}"
		echo "REIP: ${reip}"
					if [[ ("${delPeer}" == "false" && "${reIP}" == "true" ) ]]; then

						echo "Peer: ${themem} 'removed'"

					else

						echo "Peer: ${themem} was not removed....please wait..."
						echo "Authorized => ${delPeer}"
						echo "IP => ${reIP}"
						sleep 4
						peerManage

					fi
				}


			# Check to see if there are any peers
			if [[ -f ${tmpPeerFile} ]]; then

				deAuthPeers

			else

				echo "There are no peers to delete...please wait..."
				sleep 2

	
			fi


: '
   echo "[B] Back to Peer Management Main Menu"
   echo "[Z] Back to Network Configuration Main Menu"
   echo "[E] Exit Program"

'
			;;

		z|Z) # Back to Main configuration

			bash ztnetworks.bash
		;;	

		e|E)

			exit 0


		;;
		*)

			echo "Invalid Option!"
			sleep 2
			peerManage

		;;

    esac
peerManage
     echo ""

}

fi
peerManage
