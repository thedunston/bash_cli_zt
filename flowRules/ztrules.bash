#!/bin/bash


# Script to parse ZT Rules

the_network="$(echo ${1} | cut -d\. -f1)"

config_file="${1}.json"
tmp_file="ztconfig-${the_network}.tmp"


# Get the port from the config file and direction
function get_port() {

	port=$(echo "${1}" | cut -d: -f4)
	d=$(echo "${1}" | cut -d: -f3)

	# Check whether source or destination port
	if [[ "${d}" == "dport" ]]; then
 
		echo '{"end": '${port}',"not": false,"or": false,"start": '${port}',"type": "MATCH_IP_DEST_PORT_RANGE"}'

	else
		echo '{"end": '${port}',"not": false,"or": false,"start": '${port}',"type": "MATCH_IP_SOURCE_PORT_RANGE"}'

	fi
}


function get_action() {

	# check whether the rule is drop or accept
	action=$(echo "${1}"| cut -d: -f1)
	if [[ "${action}" == "accept" ]]; then

		echo '{"type": "ACTION_ACCEPT"}'

	else

		echo '{"type": "ACTION_DROP"}'

	fi

}

# check whether the protocol is tcp or udp
function get_proto() {

	proto=$(echo "${1}" |cut -d: -f 2)
	if [[ "${proto}" == "tcp" ]]; then
		
		echo '{"ipProtocol": 6,"not": false,"or": false,"type": "MATCH_IP_PROTOCOL"}'

	else
		
		echo '{"ipProtocol": 17,"not": false,"or": false,"type": "MATCH_IP_PROTOCOL"}'

	fi

}

# check whether the rule applies to the source or destination IP
# example: accept:udp:dport:53:destip:192.168.69.53/32

function get_ipnet() {

	direction=$(echo "${1}" | cut -d: -f 5)
	the_ip=$(echo "${1}" | cut -d: -f 6)

	if [[ "${direction}" == "destip" ]]; then

		  echo '{"type": "MATCH_IPV4_DEST","not": false,"or": false,"ip": "'"${the_ip}"'"}'

	else

		  echo '{"type": "MATCH_IPV4_SRC","not": false,"or": false,"ip": "'"${the_ip}"'"}'
		  

	fi

}

# This is for a rule where there is src/dst ip that applies to another src/dst ip
# example: accept:udp:sport:53:srcip:192.168.69.53/32:destip:192.168.69.0/24

function get_ipnet2() {

	direction=$(echo "${1}" | cut -d: -f 7)
	the_ip=$(echo "${1}" | cut -d: -f 8)

	if [[ "${direction}" == "destip" ]]; then

		  echo '{"type": "MATCH_IPV4_DEST","not": false,"or": false,"ip": "'"${the_ip}"'"}'

	else

		  echo '{"type": "MATCH_IPV4_SRC","not": false,"or": false,"ip": "'"${the_ip}"'"}'
		  

	fi

}


# Create header for the temporary config file
echo '{"rules": [' > ${tmp_file}

###  Processes the rules in the config file: ztrules ###

# Read the flow rules config file one line at a time
while read line; do

	# IPv4
        if  [[ "${line}" =~ ^accept:ipv4 ]]; then

                echo '{"etherType": 2048,"not": true,"or": false,"type": "MATCH_ETHERTYPE"},' >> ${tmp_file}

        fi

	# ARP
        if [[ "${line}" =~ ^accept:arp ]]; then

		echo '{"etherType": 2054, "not": true,"or": false,"type": "MATCH_ETHERTYPE"},' >> ${tmp_file}

       fi 

	if [[ "${line}" =~ ^accept:ipv6 ]]; then

		echo '{"etherType": 34525,"not": true,"or": false,"type": "MATCH_ETHERTYPE"},' >> ${tmp_file}

	fi
	# IPv6

	# TEMPORARY but follows the default rule in zerotier network controllers.
	if [[ "${line}" =~ ^end:main:protocols ]]; then

		echo '{"type": "ACTION_DROP"},' >> ${tmp_file}

	fi

		# GET ACTION
		theact=$(get_action "${line}")

	# Match accept:proto:port
	if [[ "${line}" =~ ^(accept|drop):(tcp|udp):(dport|sport):([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$ ]]; then

		# Port
		port=$(get_port "${line}")

		# Get Protocol
		proto=$(get_proto "${line}")

		act=$(get_action "${line}")

		# Write Results
		echo ''${proto}','${port}','${act}',' >> ${tmp_file}

	fi

	#Match accept:udp:dport:53:destip:192.168.69.53/32
	if [[ "${line}" =~ ^(accept|drop):(tcp|udp):(dport|sport):([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5]):(destip|srcip):[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
		# Port
		port=$(get_port "${line}")

		# Get Protocol
		proto=$(get_proto "${line}")

		act=$(get_action "${line}")

		ipnet=$(get_ipnet "${line}")

		# Write Results
		echo ''${proto}','${port}','${ipnet}','${act}',' >> ${tmp_file}

	fi

	# Match accept:tcp:dport:22:srcip:192.168.69.40/32:destip:192.168.69.217/32
	if [[ "${line}" =~ ^(accept|drop):(tcp|udp):(dport|sport):([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5]):(destip|srcip):[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}:(destip|srcip):[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
		# Port
		port=$(get_port "${line}")

		# Get Protocol
		proto=$(get_proto "${line}")

		act=$(get_action "${line}")

		ipnet=$(get_ipnet "${line}")

		ipnet2=$(get_ipnet2 "${line}")

		# Write Results
		echo ''${proto}','${port}','${ipnet}','${ipnet2}','${act}',' >> ${tmp_file}

	fi

	if [[ "${line}" == "drop:udp" ]]; then


		# Write Results
		echo '{"ipProtocol": 17, "not": false, "or": false, "type": "MATCH_IP_PROTOCOL" },{"type": "ACTION_DROP"},' >> ${tmp_file}

	fi		


	# Drops all tcp packets that don't have a matching rule above.
	# based on suggestion from zerotier manual
	# https://www.zerotier.com/manual/#3_4_1
	if [[ "${line}" == "drop:tcp" ]]; then

		# Write Results
		echo ' {"mask": "0000000000000002","not": false,"or": false,"type": "MATCH_CHARACTERISTICS"},{"mask": "0000000000000010","not": true,"or": false,"type": "MATCH_CHARACTERISTICS"},{"type": "ACTION_DROP"},' >> ${tmp_file}

	fi		

	# DEFAULT ACTION for flow rules
	if [[ "${line}" == "default:accept" ]]; then

		# Write Results
		echo '{"type": "ACTION_ACCEPT"}' >> ${tmp_file}

	fi		

	if [[ "${line}" == "default:drop" ]]; then

		# Write Results
		echo '{"type": "ACTION_DROP"}' >> ${tmp_file}

	fi

done < ${1}

# End of the ztrules files for json format
echo '],"capabilities": [],"tags": []}' >> ${tmp_file}

# put all json created rules on one line
tr -d '\n' < ${tmp_file} > ${config_file}

cat ${config_file} | jq 

if [[ $? -ne 0 ]]; then

	echo "Error creating firewall ruleset, please check your rules syntax...please wait"
	sleep 3

else

	j="$(cat ${config_file})"
	curl -X POST  -H "X-ZT1-Auth: $(cat /var/lib/zerotier-one/authtoken.secret)" -d "${j}" "http://localhost:9993/controller/network/${the_network}"

fi
