#! /bin/bash
# C Mahmoud Basset
# v13/11/2012 



if [ ! -f ./lib_snmp.sh ]
then
	echo "fichier lib_snmp.h introuvable"
	exit 1
fi
. lib_snmp.sh

###
### le coeur de l intelligence
### pour switch non cisco/passport car ce sont les macs / port, indepedemment des vlans
###
function get_macs_noncisco() {
	local i
	local prt
	local macc
	local ifi
	local ifname
	local p

	# on reccupere la table MAC dans un fichier
	snmpwalk -On -v2c -c $2  $1 .1.3.6.1.2.1.17.4.3.1 > /tmp/walk.$1 

# j avoue c barbarissime
# on imprime la MAC plus le 6-tuple qui apparait dans l'OID 
# 1.3.6.1.2.1.17.4.3.1.6tuple contient  un STRING qui est la MAC 
# 1.3.6.1.2.1.17.4.3.2.6tuple contient  un int qui est le port ID 
# je me m'en fous je prend le 6-tuple et je l ecris avec awk en HEXA

	for i in ` cat /tmp/walk.$1 | grep "1.3.6.1.2.1.17.4.3.1.1" | awk '{print $1}' | awk -F"." '{printf("%d.%d.%d.%d.%d.%d %02x:%02x:%02x:%02x:%02x:%02x\n",$(NF-5),$(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF, $(NF-5),$(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF)}' `
	do
		#ici on recuppere la chaine  d1.d2.d3.d4.d5.d6 x1:x2:x3:x4:x5:x6
	    	nde=`echo $i| awk '{print $1}' ` 
	  	macc=`echo $i| awk '{print $2}' `
		# on reccupere le ou les ifIndex
        	prt=(`grep "1.3.6.1.2.1.17.4.3.1.2" /tmp/walk.$1 | grep "$nde " | awk '{print $NF}' `)
        	# la subtilite est qu une mac est parfois sur plusieurs vlan, donc $prt peut contenir plusieurs ports
        	for p in ${prt[*]}
        	do
			#bug alcatel, la table  dot1dTpFdbPort  contient le **IfIndex*** non pas le **BridgePortID** comme sur Nortel/cisco
			#if [ $3 == "Alcatel" ] 
			if [ $3 == "Alcatesdsdl" ] 
			then
				ifname=${table_ifDescr[$p]} 
				alias=${table_ifAlias[$p]}
			else
				ifi=${table_ifIndex[$p]}
				ifname=${table_ifDescr[$ifi]}
				alias=${table_ifAlias[$ifi]}
			fi
			# si le ifname est null, c'est qu'il s agit d'une MAC du switch
			if (( ${#ifname} < 2 ))
			then
				ifname=SELF
			fi
        	       	echo  "$mhouost;$ifname;$macc;NA;$alias"
				
        	done
	done 
}
####
#### pareil mais pour cisco/passport
#### il faut le faire par vlan 
#### 
function get_macs_cisco () {
	local c
	local y
	local i
	local ifi
	local ifname
	local p

	for y in  ${vlans[*]} 
	do
		snmpwalk -On -v2c -c $2@$y $1 .1.3.6.1.2.1.17.4.3.1 > /tmp/walk.$1.$y
		for i in ` cat /tmp/walk.$1.$y | grep "1.3.6.1.2.1.17.4.3.1.1" | awk '{print $1}' | awk -F"." '{printf("%d.%d.%d.%d.%d.%d %02x:%02x:%02x:%02x:%02x:%02x\n",$(NF-5),$(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF, $(NF-5),$(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF)}' `
		do
			nde=`echo $i| awk '{print $1}' `
        		macc=`echo $i| awk '{print $2}' `
			prt=(`grep "1.3.6.1.2.1.17.4.3.1.2" /tmp/walk.$1.$y | grep "$nde " |awk '{print $NF}' `)
        		for p in ${prt[*]}
        		do	
				if [ $3 == "Passport" ]
				then
					ifname=${table_ifDescr[$p]} 
					alias=${table_ifAlias[$p]} 
				else
					ifi=${table_ifIndex[$p]}
					ifname=${table_ifDescr[$ifi]}
					alias=${table_ifAlias[$ifi]}
				fi
				if (( ${#ifname} < 2 ))
				then
					ifname=SELF
				fi
				echo "$mhouost;$ifname;$macc;$y;$alias"
				#echo "$mhouost $ifname $macc $ifi $p [vlan $y]"
			done
		done
	done
}

function get_macs () {
	if [ $3 ==  "Cisco" ] || [ $3 == "Passport" ]
	then
		get_macs_cisco $1 $2 $3
	else 
		get_macs_noncisco $1 $2 $3
	fi
}


IFS=$(echo -en "\n\b")

function get_all_switch() {
	swlist=$1
	for entry in `cat $swlist|grep -v "^#"`
	do
		# switch 
		s=`echo $entry| awk -F"--" '{print $2}'`
		# communaute
		com=`echo $entry| awk -F"--" '{print $3}'`
		# mettre une liste de port ignore (uplink, trunk interswitch) 1/25|1/49|Po1
		uplinks=`echo $entry| awk -F"--" '{print $4}'`

		mhouost=`get_hostname $s $com`
		if [ -z $mhouost ]
		then
			echo "### $s repond pas"
			continue
		fi

		echo "### $mhouost $s Uplinks $uplinks"
		os=`get_os $s $com`
		get_ifname $s $com $os
	
		# si c'est un Cisco il faut reccuperer les vlans avant de reccuperer la table de Ifindex
		if [ $os == "Cisco" ] 
		then
			get_cisco_vlans $s $com
		elif [ $os == "Passport" ]
		then
			get_passport_vlans $s $com
		fi
		get_BridgePort_Ifindex $s $com $os
		get_ifAlias $s $com

		if [ ! -z $uplinks ]
		then
			get_macs $s $com $os| egrep -v $uplinks
		else
			get_macs $s $com $os
		fi
	done
}

function main() {
        if [ $1 == "single" ]
        then
                mhouost=`get_hostname  $2 $3`
                echo $mhouost
                if [ -z $mhouost ]
                then
                        echo $1 [communaute $2] ne repond pas
                	exit 1
                fi
		os=`get_os $2 $3`
		get_ifname $2 $3 $os > /dev/null
		if [ $os == "Cisco" ] 
		then
			get_cisco_vlans $2 $3
		elif [ $os == "Passport" ]
		then
			get_passport_vlans $2 $3
		fi
		get_BridgePort_Ifindex $2 $3 $os
		get_ifAlias $2 $3
		get_macs $2 $3 $os
	elif [ $1 == "file" ]
	then
		get_all_switch $2
	else
		echo "$O [single|file] @opts"
	fi
}


if (($# <= 1 ))
then
	echo "$0 [file|single] opt"
	echo $0 file @fichier_sw_list
	echo $0 single @IP @communaute
	echo ""
	echo format du fichier :
	echo name--ip--communaute--uplinks
	exit 1
fi
main $1 $2 $3
