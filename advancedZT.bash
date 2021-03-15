#!/bin/bash

# This is run on the self-hosted controller workstation because the settings only apply to this host
# Currently only allowManagementFrom and interfacePrefixBlacklist are supported
# To modify the local.conf file.
# The default directory where it should be found is the root of the zerotier directory
# which is "/var/lib/zerotier-one" directory
# eg: /var/lib/zerotier-one/local.conf
# Source: https://github.com/zerotier/ZeroTierOne/tree/master/service

source "functions.bash"

if [[ -f ${bkLocalConfig} ]]; then

	rm -f ${bkLocalConfig}

fi

# Local controller ID
CONTROLLER_ID=$(zerotier-cli info | cut -d' ' -f 3)

function copyBkConfig() {

	cp ${localConfig} ${bkLocalConfig}

}

function copyConfig() {

	cp ${bkLocalConfig} ${localConfig}

}

function menuHeader() {

	clear
	echo "########################################################"
	echo "    ${1}"
	echo "########################################################"

}

function advZT() {
clear

	echo
	echo "This menu allows editing the local.conf file which has options to modify"
	echo "various settings provided by ZeroTier.  More information is available here"
	echo "# Source: https://github.com/zerotier/ZeroTierOne/tree/master/service"
	echo "Currently only \"allowManagementFrom\" and \"interfacePrefixBlacklist\""
	echo "are supported."
	read -p "Press Enter when done."
	menuHeader "Here you can edit the local.conf file."
	echo ""
	echo "1. Edit IPs/Nets that can manage this controller"
	echo "2. Edit Interfaces to blacklist"
	echo "[E]xit"
	read -p "Select a numeric option to manage the local.conf file: " option
	
	if ! [[ -f ${localConfig} ]]; then
	
		# Copy the file template.
		cp ${localConfigTemplate} ${localConfig}

	
	fi

	current_val=$(grep allowManagementFrom ${localConfig} | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}')
	case ${option} in

		# Get the current value

		1)

			function manageChoice () {

				# Check if the file is new
				menuHeader "Manage IPs/Nets that can manage this controller"
				echo "1. Enter a new IP/Network"
				echo "2. Delete an IP/Network"
				echo "[B]ack to main menu"
				read -p "Please enter a numeric option: " mChoice

			}

			manageChoice

			# Submenu case statement
			case ${mChoice} in

			1)

				# Check the IP
				echo ""
			
				# Set the IPs allowed to manage this controller
				function ipAllow() {
	
					menuHeader "IPs and networks must contain masks.  Separate each IP/Net with a space."
					echo "eg. 192.168.0.1/32"
					echo "eg. 192.168.1.1/32 192.168.1.2/32"
					echo "eg. 192.168.0.1/32 192.168.2.0/24"
					read -p "Please enter an IP or Network that can manage this controller or Enter to go back to the main menu: " theIP
				
					if [[ "${theIP}" == "" ]]; then

						advZT

					fi
					# Check the IPs/Nets entered
					if [[ "${theIP}" =~ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}  ]]; then

						# Check the IPs/Nets provided
						for eachIPNet in ${theIP}; do
		
							ipnet_chk ${eachIPNet} ipAllow
	
						done

					else

						ipAllow

					fi
	
				}
	
				ipAllow
	
	
				# Add the IPs
				if [[ "${current_val}" == "" ]]; then
	
					# Format the IP
					ips=$(echo ${theIP} | sed -e 's/^/"/g;s/$/"/g;s/ /","/g;s/ //g;s/\//\\\//g')

					# Copy current local.conf to backup config
					copyBkConfig

					# Make changes to the backup file
					sed -i "/allowManagementFrom/s/\[\]/\[${ips}\]/g" ${bkLocalConfig}
					cat ${bkLocalConfig} | jq
					chk_jq "" ipAllow

					# If in proper json format then replace the local.conf file.
					copyConfig
					rm ${bkLocalConfig}
					systemctl restart zerotier-one
					allDone "IP was added" ipAllow
	
				else

					# Concatenate the existing allowed IPs/Nets
					ips=$(echo "${theIP} ${current_val}" | tr ' ' '\n' |sort -u | paste -sd ' ' - | sed -e 's/^/"/g;s/$/"/g;s/ /","/g;s/ //g;s/\//\\\//g')

					# Copy current local.conf to backup config
					copyBkConfig
					
					# Add the new IP/Net
					sed -i -e "/allowManagementFrom/s/\[.*\]/\[${ips}\]/g" ${bkLocalConfig}
					cat ${bkLocalConfig} | jq
					chk_jq ipAllow

					# If in proper json format then replace the local.conf file.
					copyConfig
					rm ${bkLocalConfig}
					systemctl restart zerotier-one
					allDone "IP was added" ipAllow
	
				fi

			;;

			2) # Delete the IPs/Nets

				function delIPNet() {

					menuHeader "IP and/or Networks to delete"
					listLocalConf allowManagementFrom
					
					# Replace spaces with pipe
					delPatt=$(echo ${currSetting} | sed 's/ /|/g')

					# Remove IPs/Nets
					del=$(echo ${ENTITIES} | tr '  ' '\n' | egrep -v "${delPatt}" | sort -u | paste -sd ' ' -| sed -e 's/^/"/g;s/$/"/g;s/ /","/g;s/ //g;s/\//\\\//g')

					copyBkConfig

					if [[ "${del}" == "\"\"" ]]; then

						sed -i -e "/allowManagementFrom/s/\[.*\]/\[\]/g" ${bkLocalConfig}
	
					else

						sed -i -e "/allowManagementFrom/s/\[.*\]/\[${del}\]/g" ${bkLocalConfig}

					fi

					# Check the proper json syntax
					cat ${bkLocalConfig} | jq
					chk_jq "" delIPNet
					
					copyConfig
					systemctl restart zerotier-one
					allDone "IP was deleted" ipAllow

				}

				delIPNet

			;;

			b|B)

				advZT

			;;	

			e|E)

				exit 0

			;;

			*)  read -p "Invalid option. Press ENTER when done."

				manageChoice

			esac

		;;
	
		2)

			current_if=$(grep interfacePrefixBlacklist ${localConfig} | egrep -o '\[.*\]' | sed -e 's/","/ /g;s/\[//g;s/\]//g;s/[",]/_/g;s/_//g')

			clear
			function manageIF() {
				
				menuHeader "Add Interfaces"
				echo "1. Add Interface."
				echo "2. Delete Interface"
				echo "[B]ack to main menu"
				read -p "Please select a numeric value: " choice

				case ${choice} in

					1) # Add interface

						listIf

						# Parse the interfaces listed
						x=$(echo ${current_if} | tr '\n' ' ' | sed "s/$/${intF}/g" | tr ' ' '\n' | sort -u)

						# Make the changes to the temporary local.conf file first
						copyBkConfig
						ips=$(echo ${x} |tr '\n' ' '| sed -e 's/^/"/g;s/$/"/g;s/ /","/g;s/ //g;s/,""//g')
						sed -i "/interfacePrefixBlacklist/s/\[.*\]/\[${ips}\]/g" ${bkLocalConfig}

						cat ${bkLocalConfig} |jq
						chk_jq "" manageIF

						# If their are no errors from the json object then copy to the ZT home directory
						copyConfig
						systemctl restart zerotier-one
						allDone "Interface was added" manageIF

					;;
					2) # Remove interface

						menuHeader "Remove Current Interfaces"
						listLocalConf interfacePrefixBlacklist

						x=$(echo ${current_if} | sed "s/${currSetting}//g" |sort -u | tr '\n' ' ' |grep '.')

						copyBkConfig
						ips=$(echo ${x}| sed -e 's/^/"/g;s/$/"/g;s/ /","/g;s/ //g;s/_//g')
						sed -i "/interfacePrefixBlacklist/s/\[.*\]/\[${ips}\]/g" ${bkLocalConfig}

						cat ${bkLocalConfig} |jq
						chk_jq "" manageIF
						copyConfig
						systemctl restart zerotier-one
						allDone "Interface was added" manageIF

					;;

					b|B)

						advZT
					;;

					*)

						read -p "Invalid option. Press Enter to continue."
						manageIF

					;;

				esac

			}
			manageIF
	
		;;

		e|E)

			exit 0
		;;
	
		*)

			read -p "Invalid option. Press Enter to continue."
			advZT
	
		;;

	esac

advZT
}

advZT
