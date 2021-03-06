#!/bin/bash

source "functions.bash"

tmpRouteFile='tmp/ztroutesfile.tmp'


	rm -f tmp/ztexistjson.tmp
	rm -f tmp/ztexistjson2.tmp
allNets

#theNet=$(echo "${net}" | awk ' { print $1 } ')

del_temp

# Set array to add routes
declare -a targetArray

function get_routes() {

	rm -f tmp/ztexistjson.tmp

	currNet
	# Default index for routes
	COUNTER=0

	# Get the routes for the network
	x=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${theNet}" | jq -r '.routes[].target' |wc -l)
	
	# set the number of available routes - 1
	num=$(($x-1))
	
	# Begin format for files with routes.
	echo '{ "routes": [' >> tmp/ztexistjson.tmp
	
	# Loop through the routes
	until [ $COUNTER -gt $num ]
	do
	
		t=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${theNet}/" | jq -r ".routes[$COUNTER].target")
		v=$(curl -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)"  "http://localhost:9993/controller/network/${theNet}/" | jq -r ".routes[$COUNTER].via")

    		((COUNTER++))

		# Formatting the route
		ta='{"target": "'${t}'", "via": "'${v}'"},'

		# Add route to array
		targetArray+=(${ta})
	
		# Used for printing to the screen
		# The column command will replace the three underscores with spaces for
		# Clean formatting
		echo "${t}___${v}" >> ${tmpRouteFile}

		# Write the formatted route to the temp file
		echo "${ta}" >> tmp/ztexistjson.tmp

	done
	
}

function allDone() {

	read -p "Press Enter when done."

}
function menu() {

	clear

	echo "1. List routes"
	echo "2. Add a route"
	echo "3. Delete a route"
	echo "[E]xit back to main ZT Menu"
	read -p "Please select a number value next to the options. " choice

	case "${choice}" in

		1) # list routes

			echo "Destination___Gateway" > ${tmpRouteFile}

			get_routes
			currNet

			clear
			echo ""
			cat ${tmpRouteFile} | column -t -s"___"
			del_temp
			currNet
			allDone

		;;

		2)  # Add a route

			echo "Destination___Gateway" > ${tmpRouteFile}

			clear
			get_routes

			theNet=$(cat ${ztnetFile})
			function get_dest() {
			
				read -p "Please enter the destination network or host and netmask or 'E' to exit: " dest

			}

			get_dest
			
			ip_chk "${dest}" "get_dest"
			echo ""

			function get_gateway() {
			
				read -p "Please enter the host to be the gateway and netmask or 'E' to exit: "  gateway

			}

			get_gateway
			
			ip_chk "${gateway}" "get_gateway"

			if [[ "${gateway}" == "default" ]]; then

				gateway=""

			fi

			# Get existing routes
			currRoutes=$(echo ${targetArray[*]} | sed 's/} {/},{/g')

			if [[ "{target: ${dest}, via: ${gateway}}" =~ "${currRoutes}" ]]; then

				echo "Route already exists."
				allDone
				currNet
				menu

			else

				# Add new route to the temp file for parsing
				echo '{"target": "'${dest}'", "via": "'${gateway}'"} ]}' >> tmp/ztexistjson.tmp

				# Put all routes on one line
				cat tmp/ztexistjson.tmp | awk 'ORS=/,$/?" ":"\n"' >  tmp/ztexistjson2.tmp

				# Create the json formatted string containing the existing and new route
				json=$(cat tmp/ztexistjson.tmp | jq --argjson curr "$(<tmp/ztexistjson2.tmp)" '.routes += [$curr]')
#				rm -f tmp/ztexistjson.tmp

				chk_jq

				# Add the route
				addRoute=$(curl -X POST -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -d "${json}" "http://localhost:9993/controller/network/${theNet}"| jq '.routes')
			fi

			if [[ ("${dest}" =~ "${addRoute}" && "${gateway}" =~ "${addRoute}") ]]; then

				echo "Route was not added."
				rm -f tmp/ztexistjson.tmp
				rm -f tmp/ztexistjson2.tmp
				allDone
				del_temp

			else

				echo "Route was added."
				del_temp			
				rm -f tmp/ztexistjson.tmp
				rm -f tmp/ztexistjson2.tmp
				allDone

			fi

			;;

		3) # Delete a route
			get_routes

			currNet
			# Dynamic menu from:
		        # https://gist.github.com/nhoag/c202b3dd346668d6d8c1
		        ENTITIES=$(cat ${tmpRouteFile} | column -t -s "___")
		        SELECTION=1
		        
		        while read -r line; do
		        
		                echo "$SELECTION) $line"
		                ((SELECTION++))
		
		        done <<< "$ENTITIES"
		        
		        echo "B) To go back to the main menu"
		        ((SELECTION--))
		        
		        echo
		        printf 'Select the number next to the route to delete: '
		        read -r opt
		
		        if [[ ${opt} =~ ^(b|B)$ ]]; then
		
		                menu
		        fi
			if [[ $(seq 1 $SELECTION) =~ $opt ]]; then
		
		                # Get the selection value
		                ther=$(sed -n "${opt}p" <<< "$ENTITIES")
				
				# Destination
				d=$(echo ${ther} | awk ' { print $1 } ' | sed 's/\//\\\//g')

				# Gateway
				g=$(echo ${ther} | awk ' { print $2 } ' |sed 's/\//\\\//g')
		
		        fi

			# Prompt to delete route
			read -p "Are you sure you want to delete the route => ${ther}? [y|N] " choice

			if [[ "${choice}" =~ ^(y|Y)$ ]]; then

				# Delete the line containing the route
				sed -i "/\"target\": \"${d}.*\"via\": \"$g/d" tmp/ztexistjson.tmp

				# Add end of the routes object
				echo ']}' >> tmp/ztexistjson.tmp

				# Put all routes on one line
				cat tmp/ztexistjson.tmp | awk 'ORS=/,$/?" ":"\n"' >  tmp/ztexistjson2.tmp

				# Remove extraneous comma
				sed -i 's/, \]}/\]}/g' tmp/ztexistjson2.tmp

				# Create the json formatted string containing the 
				json=$(cat tmp/ztexistjson2.tmp | jq . )
#				rm -f tmp/ztexistjson.tmp

				chk_jq

				# Delete the route
				addRoute=$(curl -X POST -s -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -d "${json}" "http://localhost:9993/controller/network/${theNet}"| jq '.routes')

			else 

				echo "Route will not be deleted."
				allDone
				del_temp
				rm -f tmp/ztexistjson.tmp
				currNet
				menu

					
			fi

			if ! [[ ("${d}" =~ "${addRoute}" && "${g}" =~ "${addRoute}") ]]; then

				echo "Route was not deleted."
				del_temp
				currNet
				allDone

			else

				echo "Route was deleted added."
				get_routes
				cat ${tmpRouteFile} | column -t -s "___"
				currNet
				allDone
				del_temp

			fi
			;;

		e|E) # Exit

			exit 0

			;;

		*) echo "Invalid Option"
			sleep 2
			menu

			;;

	esac

	menu

}

menu
