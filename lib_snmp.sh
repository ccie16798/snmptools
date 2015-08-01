#! /bin/bash
# C Etienne Basset
# v24/10/2014 
#
# Ensemble de fonctions SNMP pour reccuperer pleins d'infos sur un switchs


#OIDs standard
#=============
OID_HOSTNAME=1.3.6.1.2.1.1.5.0
OID_sysDescr=1.3.6.1.2.1.1.1.0
OID_sysContact=1.3.6.1.2.1.1.4.0
OID_ifDescr=1.3.6.1.2.1.2.2.1.2
OID_ifType=1.3.6.1.2.1.2.2.1.3
OID_ifAlias=1.3.6.1.2.1.31.1.1.1.18 #le nom configue sur le port 
OID_ifOperStatus=1.3.6.1.2.1.2.2.1.8
OID_ifSpeed=1.3.6.1.2.1.2.2.1.5
OID_ifAdminStatus=1.3.6.1.2.1.2.2.1.7
OID_dot1dBasePortIfIndex=1.3.6.1.2.1.17.1.4.1.2


# table de vlans (Cisco)
#=======================
OID_CiscoVTPstate=1.3.6.1.4.1.9.9.46.1.3.1.1.2
OID_ciscoVlanName=1.3.6.1.4.1.9.9.46.1.3.1.1.4.1

# OID pour configuration SWITCHPORT (access, trunk)
OID_vlanTrunkPortDynamicStatus=1.3.6.1.4.1.9.9.46.1.6.1.1.14
OID_vlanTrunkPortVlansEnabled=1.3.6.1.4.1.9.9.46.1.6.1.1.4
# awk '/^(\.).*/{ if ( FNR > 1 ) printf "\n"; gsub( "\r" , "" , $0 ); printf "%s", $0; next } { gsub( "\r" , "" , $0 );  printf "%s", $0 } END{ printf "\n" }' | awk -F"STRING:" '{print $2}'
OID_vmVlan=.1.3.6.1.4.1.9.9.68.1.2.2.1.2

OID_NORTEL_rcVlanPortType=1.3.6.1.4.1.2272.1.3.3.1.4
OID_NORTEL_vlanTrunkPortVlansEnabled=1.3.6.1.4.1.2272.1.3.3.1.3
OID_NORTEL_rcVlanPortDefaultVlanId=1.3.6.1.4.1.2272.1.3.3.1.7



#OID_dot1dTpFdbAddress   1.3.6.1.2.1.17.4.3.1.6tuple contient  un STRING qui est la MAC
#OID_dot1dTpFdbPort  1.3.6.1.2.1.17.4.3.2.6tuple contient  un int qui est le port ID
#OID_BCAST=IF-MIB::ifInBroadcastPkts

OID_PASSPORT_MLTIFINDEX=1.3.6.1.4.1.2272.1.17.10.1.11
OID_PASSPORT_VLANS=1.3.6.1.4.1.2272.1.3.2.1.1
OID_PASSPORT_VLANS_NAME=1.3.6.1.4.1.2272.1.3.2.1.2


OID_ALCATEL_VLAN_NAME=1.3.6.1.2.1.17.7.1.4.3.1.1
OID_ALCATEL_VLAN_ID=1.3.6.1.4.1.6486.800.1.2.1.4.1.1.2.1.1.7
OID_ALCATEL_VLAN_STATUS=1.3.6.1.4.1.6486.800.1.2.1.3.1.1.2.1.1.3

WALK=/usr/bin/snmpwalk
if [ ! -f $WALK ]
then
	echo "$WALK not found, aborting"
	exit 1
fi
# un petit programme en C pour convertir un bitmap de vlan (sur un trunk) en liste de vlan lisibles
if [ -f ./bitmap_to_vlans ]
then 
	BITMAP_TO_VLAN=./bitmap_to_vlans
else
	BITMAP_TO_VLAN=tee
fi

# Toutes les tables qui peuvent etre remplies via SNMP
# ====================================================
# table table_ifAlias		: le champ description configure sur l interface
# table table_ifDescr		: le nom de l interface
# table table_ifType		: le type d'interface (ethernet, Vlan, Port-Channel)
# table table_ifIndex		: l'index de l'interface
# table_ifSpeed			: la vitesse du port
# table table_ifOperStatus	: le status operationnel du port (up, down)
# table table_ifAdminStatus	: le status administratif du port (shut, no shut)
# table vlans			: tous les vlans definis sur le switch (excluant les vlans speciaux 1001-1005)
# table vlans_name		: le nom des vlan

# table_access_vlans		: l'access vlan configure sur un port
# table_trunk_vlans		: la liste des vlans autorises sur un trunk
# table_switchport		: le type de port (trunk=1, access=2)

# Toutes les fonctions qui peuvent etre reutilisees dans d'autres programmes
# ==========================================================================

# function get_ifType
# function get_ifAlias
# function get_ifAdminStatus
# function get_ifOperStatus
# function get_os
# function get_hostname
# function get_cisco_vlans
# function get_passport_vlans
# function get_vlans
# function get_vlans_name
# function get_BridgePort_Ifindex
# function get_ifSpeed

# function get_trunk_vlans
# function get_access_vlans
# function get_switchport 
###

##
## petite fonction de daube pour transformer une chaine de vlan en hexadecimal vers une liste decimale
## 00 01 00 50 00 51 devient 1 80 81
##
function hex_to_decimal () {
	local j
	local i
	local c
	local vlan

	# on remet les espace dans le IFS pour traiter la chaine pourrie
	IFS=$(echo -en "\n\b ")
	c=0
	for j in $1
	do
		if (($c%2 == 0))
        	then
			i=0x$j
			if (($c > 0))
			then
				echo -n " "
			fi
		else
			vlan=$((8*$i + 0x$j))
			echo -n $vlan
		fi
        	c=$(($c+1))
	done
	echo 
	IFS=$(echo -en "\n\b")
}
### qques fonctions pour determiner l'os 
###

# pour les 2 tables suivantes
# si snmpget sysDescr | table_os_pattern[i] est non null, alors l'OS est table_os[i]
# il faut donc mettre les OS et les "os_pattern" DANS LE MEME ORDRE

table_os_pattern=("Nortel|Business Policy Switch|BayStack|Avaya|Ethernet Routing Switch" "Passport|ERS-8610" "ERS-16" "Cisco" "alcatel")
table_os=("Nortel" "Passport" "ERS-16XX" "Cisco" "Alcatel")


function get_os () {
	local i
	local a
	local b
	local c
	local z

	a=`snmpget -Ov -v2c -c $2 $1 $OID_sysDescr`
	b=`snmpget -Ov -v2c -c $2 $1 $OID_sysContact`
	c=$a$b

	for i in ${!table_os[*]}
	do
		os_string=${table_os_pattern[$i]}
		z=`echo $c | egrep -i $os_string`
		if (( ${#z} > 2 ))
		then
			echo "${table_os[$i]}"
			return
		fi
	done
	echo "Unknown"
}


function get_hostname () {
	local truc=`snmpget  -On -v2c -c $2 $1  $OID_HOSTNAME 2> /dev/null `
 # si snmpget se choppe un timeout on repond un "" chaine vide quoi
 	echo $truc| awk '{print $NF'} 2> /dev/null 
}

####
#### get_ifType $ip $com
#### pour connaitre le type d'interface (vlan, ethernet, channel)
#### cree la table  table_ifType
####
function get_ifType() {
	local i
	local ifindex
	local type

 	for i in `$WALK -On -v2c -c $2 $1 $OID_ifType`
	do
		ifindex=`echo $i   | awk '{print $1}' | awk -F"." '{print $NF}' `
		type=`echo $i   | awk  '{print $NF}' |  awk -F"(" '{print $1}'`
		table_ifType[$ifindex]=$type
		#echo $ifindex $type
	done
}


####
#### get_ifAlias $ip $com
#### pour connaitre le nom (alias) configure de l'interface
#### cree la table  table_ifAlias
####
function get_ifAlias() {
        local i
        local ifindex
        local alias

	unset table_ifAlias
        for i in `$WALK -On -v2c -c $2 $1 $OID_ifAlias`
        do
                ifindex=`echo $i| awk '{print $1}' | awk -F"." '{print $NF}' `
                alias=`echo $i | awk  -F"STRING: " '{print $NF}' `
                table_ifAlias[$ifindex]=$alias
                #echo $ifindex $alias
        done
}


####
#### get_cisco_vlans $ip $com
#### cree une table avec tous les vlans du switch
####
function get_cisco_vlans () {
	local i
	local c=0
	local j

	unset vlans
	# on exclue les vlan 1002-1005 (vlan speciaux)
	for i in `$WALK -v2c -c $2 $1 $OID_CiscoVTPstate | egrep -v "1002|1003|1004|1005"`
	do
		j=`echo $i   | awk '{print $1}'	| awk -F"." '{print $NF}' `
		vlans[$c]=$j
		((c=$c+1))
	done
}

####
#### get_alcatel_vlans $ip $com
#### cree une table avec tous les vlans du switch
####
function get_alcatel_vlans () {
	local i
	local c=0
	local j

	unset vlans
	# on exclue les vlan 1002-1005 (vlan speciaux)
	for i in `$WALK -v2c -c $2 $1 $OID_ALCATEL_VLAN_NAME | egrep -v "1002|1003|1004|1005"`
	do
		j=`echo $i   | awk '{print $1}'	| awk -F"." '{print $NF}' `
		vlans[$c]=$j
		((c=$c+1))
	done
}


####
#### sur passport
####
#### la requete table MAC est par vlan sur la communaute COM@VLAN_ID
function get_passport_vlans () {
        local i
        local c=0
        local j
	
	unset vlans
        # on exclue les vlan 1002-1005 (vlan speciaux)
        for i in `$WALK -v2c -c $2 $1 $OID_PASSPORT_VLANS | egrep -v "1002|1003|1004|1005"`
        do
                j=`echo $i | awk '{print $1}' | awk -F"." '{print $NF}' `
		# y a un vlan ZERO sur cette table passport
		if (($j > 0))
		then
                	vlans[$c]=$j
                	((c=$c+1))
		fi
        done
}

##
## get_vlans_name $ip $com $os
## rempli la table vlans_name
## il faut avoir execute get_vlans AVANT
## 
function get_vlans_name () {
        local i
        local j
	local vname
	local OID

	if [ $3 == "Cisco" ]
	then
		OID=$OID_ciscoVlanName
	elif [ $3 == "Nortel" ] || [ $3 == "Passport" ] || [ $3 == "ERS-16XX" ]
        then
		OID=$OID_PASSPORT_VLANS_NAME
	else
		return
	fi
	unset vlans_name

        for i in `$WALK -v2c -c $2 $1 $OID | egrep -v "1002|1003|1004|1005"`
        do
                j=`echo $i | awk '{print $1}' | awk -F"." '{print $NF}' `
		vname=`echo $i | awk -F"STRING: " '{print $NF}'`
		#echo $j $vname
               	vlans_name[$j]=$vname
	done
}

##
## get_vlans $ip $communaute $os
## appelle la fonction specifique pour remplir la table vlans
##
function get_vlans () {
	local i

	if [ $3 == "Cisco" ]
	then
		get_cisco_vlans $1 $2
	elif [ $3 == "Nortel" ] || [ $3 == "Passport" ] || [ $3 == "ERS-16XX" ]
	then
		get_passport_vlans $1 $2
	
	elif [ $3 == "Alcatel" ]
	then
		get_alcatel_vlans $1 $2
	else
		i=0
	fi
}


####
#### get_ifname $ip $com $os
#### cree un tableau @table_ifDescr qui contient le nom des interfaces
#### comme chaque constructeur met une chaine pourrav a part cisco, il faut tenter de decoder
#### pour lancer la bonne commande 
####
function get_ifname () {
	echo $3
	if [ $3 == "Nortel" ]
	then
		get_ifname_baystack $1 $2
	elif [ $3 == "Alcatel" ]
	then
		get_ifname_alcatel $1 $2
	elif [ $3 == "Passport" ] || [ $3 == "ERS-16XX" ]
	then
		get_ifname_passport $1 $2
	else
		os="Cisco"
		get_ifname_cisco $1 $2
	fi 
}


function get_ifname_baystack () {
	local i
	local name
	local ifindex
	local module

        for i in `$WALK -On -v2c -c $2 $1 $OID_ifDescr`
        do
                ifindex=`echo $i | awk '{print $1}' | awk -F"." '{print  $NF}' `
		module=`echo $i | awk '{print  $(NF-2)}' `
		# si pas stacke - Port 24  
		# si stack  Unit 2 Port 24  
		#si module GBIC  - Unit 1 Port 26 (MDA) 
		if [ $module == "Port" ]
		then
			 name=`echo $i | awk '{print  $(NF-3) "/" $(NF-1)}' `
		else
                	name=`echo $i | awk '{print  $(NF-2) "/" $NF}' `
		fi
		# si pas de modules
		name=`echo $name | sed s/-/1/`
#		echo "$module $ifindex $name"
		table_ifDescr[$ifindex]=$name
        done
}

####
####
####
function get_ifname_cisco () {
	local i
	local ifindex
	local name

        for i in `$WALK -On -v2c -c $2 $1 $OID_ifDescr`
        do
                ifindex=`echo $i | awk '{print $1}' | awk -F"." '{print  $NF}' `
                name=`echo $i | awk '{print  $NF}' `
#		echo "NAME: $ifindex $name"
                table_ifDescr[$ifindex]=$name
        done
}


function get_ifname_passport () {
	local i
	local ifindex
	local name
	local mltid

        for i in `$WALK -On -v2c -c $2 $1 $OID_ifDescr`
        do
                ifindex=`echo $i | awk '{print $1}' | awk -F"." '{print  $NF}' `
#IF-MIB::ifDescr.68 = STRING: 1000Gbic850Sx Port 1/5 Name AH2_DMZP_00S104_01BS5510
                name=`echo $i | awk '{print  $6}' `
#               echo "NAME: $ifindex $name"
                table_ifDescr[$ifindex]=$name
        done
# sur passport les MLT sont pas dans la table ifDescr...
	for i in `$WALK -On -v2c -c $2 $1 $OID_PASSPORT_MLTIFINDEX`
	do
		mltid=`echo $i | awk '{print $1}' | awk -F"." '{print  $NF}' `
		ifindex=`echo $i | awk '{print  $NF}' `
		table_ifDescr[$ifindex]="MLT-$mltid"
	done
}

####
####
function get_ifname_alcatel () {
	local i
	local ifindex
	local name
	local name2
	local channel

        for i in `$WALK -On -v2c -c $2 $1 $OID_ifDescr`
        do
		ifindex=`echo $i | awk '{print $1}' | awk -F"." '{print  $NF}' `
		name=`echo $i | awk '{print  $(NF-1) }' `
# pour un Portchannel la desc est STRING: Omnichannel Aggregate Number 6 ref 40000006 size 2
#donc je retripatouille pour avoir le numero de portchannel
		if [ $name == "size" ]
		then
			channel=`echo $i | awk '{print  $(NF-4) }' `
			table_ifDescr[$ifindex]="Po$channel"
# un GBIC module sur une carte d extension n apparait pas comme X/Y mais comme "GEXP-F-2"
# je retripatouille le $ifindex ABCD  avec A=stack_module, B=0 CD=port number
		elif [ $name == "GEXP-F-2" ]
		then
			name2="${ifindex:0:1}/${ifindex:2:2}"
			table_ifDescr[$ifindex]=$name2
		else
			table_ifDescr[$ifindex]=$name
		fi
                #echo $ifindex ${table_ifDescr[$ifindex]}
	done
}

####
#### reccupere le status operationnel des ports
#### demande d'avoir execute get_ifType AVANT
####
function get_ifOperStatus() {
	local i
	local j
	local status
	local ifType

	for i in `$WALK -On -v2c -c $2 $1 $OID_ifOperStatus`
	do
		j=`echo $i |awk '{print $1}' | awk -F"." '{print $NF} ' `
		status=`echo $i |awk '{print $NF}'| awk -F"(" '{print $1}' `
		ifType=${table_ifType[$j]}

		if [ $ifType == "ethernetCsmacd" ] ||  [ $ifType == "ieee8023adLag" ]
		then
			table_ifOperStatus[$j]=$status
		fi
	done
}

####
#### reccupere le status administratif de tous les  ports
#### demande d'avoir execute get_ifType AVANT
####
function get_ifAdminStatus() {
        local i
	local j
	local status
	local ifType

	for i in `$WALK -On -v2c -c $2 $1 $OID_ifAdminStatus`
	do 
		j=`echo $i |awk '{print $1}' | awk -F"." '{print $NF} ' `
		status=`echo $i |awk '{print $NF}' | awk -F"(" '{print $1}' `	
		ifType=${table_ifType[$j]}

		if [ $ifType == "ethernetCsmacd" ] ||  [ $ifType == ieee8023adLag ]
		then
			table_ifAdminStatus[$j]=$status
		fi
	done
}


####
#### reccupere la speed des ports
#### demande d'avoir execute get_ifType AVANT
####
function get_ifSpeed() {
        local i
	local j
	local speed1
	local speed
	local ifType

	for i in `$WALK -On -v2c -c $2 $1 $OID_ifSpeed`
	do 
		j=`echo $i |awk '{print $1}' | awk -F"." '{print $NF} ' `
		#la vitesse est en bit/sec
		speed1=`echo $i |awk '{print $NF}'`	
		ifType=${table_ifType[$j]}

		if [ $ifType == "ethernetCsmacd" ] ||  [ $ifType == ieee8023adLag ]
		then
			((speed=$speed1/1000000))
			table_ifSpeed[$j]=$speed
		fi
	done
}


###
### get_BridgePort_Ifindex $ip $communaute $os
### stocke un tableau de correspondance entre le portBridgeid et le Ifindex
###
###
function get_BridgePort_Ifindex  () {
	local i
	local ifindex
	local bp
	local v

	if [ $3 == "Cisco" ] || [ $3 == "Passport" ]
	then
		for v in  ${vlans[*]}
		do
			for i in `$WALK -On -v2c -c $2@$v $1  $OID_dot1dBasePortIfIndex`
			do
				ifindex=`echo $i | awk '{print $NF}' `
				bp=`echo $i | awk '{print $1}' | awk -F"." '{print $NF}' `
				table_ifIndex[$bp]=$ifindex
			#       echo "bridge $bp ifi $ifindex"
			done
		done
	else
		for i in `$WALK -On -v2c -c $2 $1  $OID_dot1dBasePortIfIndex`
		do
			ifindex=`echo $i | awk '{print $NF}' `
			bp=`echo $i | awk '{print $1}' | awk -F"." '{print $NF}' `
			table_ifIndex[$bp]=$ifindex
			#echo "bridge $bp ifi $ifindex"
		done
	fi
}


###
### get_switchport_status $ip $communaute $os
### rempli le tableau  table_switchport
### 
function get_switchport_status () {
	local i
	local OID
	local status
	local ifindex

	unset table_switchport
	if [ $3 == "Cisco" ]
	then
		OID=$OID_vlanTrunkPortDynamicStatus
	elif [ $3 == "Nortel" ] || [ $3 == "Passport" ] || [ $3 == "ERS-16XX" ]
	then
		OID=$OID_NORTEL_rcVlanPortType

	elif [ $3 == "Alcatel" ]
	then
		get_switchport_status_alcatel $1 $2
		return
	else
		return

	fi

	for i in `$WALK -On -v2c -c $2 $1 $OID`
	do
		ifindex=`echo $i |awk '{print $1}' | awk -F"." '{print $NF}' `
		status=`echo $i | awk '{print $NF}' `
		# status=2 ==> access  status=1 ==> trunk
		table_switchport[$ifindex]=$status
		if [ $3 == "Nortel" ] || [ $3 == "Passport" ] || [ $3 == "ERS-16XX" ]
		then
			table_switchport[$ifindex]=$((3-$status))
		fi
	done
}

#
# sur alcatel on reccupere le switchport status et les vlans / port d'un seul coup
#
function get_switchport_status_alcatel () {
	local v
	local i
	local ifi
	local status

	unset table_switchport
	unset table_trunk_vlans
	unset table_access_vlans 

	for i in `$WALK -On -v2c -c $2 $1 $OID_ALCATEL_VLAN_STATUS`
	do
		ifi=`echo $i |awk '{print $1}' | awk -F"." '{print $NF}' `
		v=`echo $i |awk '{print $1}' | awk -F"." '{print $(NF-1)}' `
		status=`echo $i |awk '{print $NF}'`
	#	echo $v $ifi $status
		if [ $status == 1 ]
		then 
			table_switchport[$ifi]=2
			table_access_vlans[$ifi]=$v
		elif [ $status == 2 ]
		then
			table_switchport[$ifi]=1
			table_trunk_vlans[$ifi]=`echo $v ${table_trunk_vlans[$ifi]}`
		fi	
	done

}

###
### get_trunk_vlans $ip $communaute $os
### rempli le tableau  table_trunk_vlans
### 
function get_trunk_vlans () {
	local tpv_oid
	local i
	local ifindex


        if [ $3 == "Cisco" ] 
	then
		unset table_trunk_vlans
		tpv_oid=$OID_vlanTrunkPortVlansEnabled
		# le awk suivant a pour but de mettre, pour chaque OID le resultat sur une seul ligne		
		for i in `$WALK -On -v2c -c $2 $1  $tpv_oid | awk '/^(\.).*/{ if ( FNR > 1 ) printf "\n"; printf "%s", $0; next } { printf "%s", $0 } END{ printf "\n" }' `
		do
			ifindex=`echo $i |awk '{print $1}' | awk -F"." '{print $NF}' `
			vlan_list=`echo $i | awk -F"STRING: " '{print $2}' | $BITMAP_TO_VLAN `
			table_trunk_vlans[$ifindex]=$vlan_list
		done
	elif [ $3 == "Nortel" ] || [ $3 == "Passport" ] || [ $3 == "ERS-16XX" ]
	then
		unset table_trunk_vlans
		tpv_oid=$OID_NORTEL_vlanTrunkPortVlansEnabled
		for i in `$WALK -On -v2c -c $2 $1  $tpv_oid | awk '/^(\.).*/{ if ( FNR > 1 ) printf "\n"; printf "%s", $0; next } { printf "%s", $0 } END{ printf "\n" }' `
		do
			ifindex=`echo $i |awk '{print $1}' | awk -F"." '{print $NF}' `
			vlan_list=`echo $i | awk -F"STRING: " '{print $2}'`
			v2=`hex_to_decimal $vlan_list`
			table_trunk_vlans[$ifindex]=$v2
		done
	elif [ $3 == "Alcatel" ]
	then
		i=1
		#on ne touche pas a la table de trunk vlan, qui a ete remplie avant par get_switchport_status dans le cas Alcatel
	else
		unset table_trunk_vlans
		return
	fi
}

###
### get_access_vlans $ip $communaute $os
### rempli le tableau  table_access_vlans
### 
function get_access_vlans () {
	local OID
	local i
	local ifindex
	local v

        if [ $3 == "Cisco" ] 
	then
		OID=$OID_vmVlan
	elif [ $3 == "Nortel" ] || [ $3 == "Passport" ] || [ $3 == "ERS-16XX" ]
	then
		OID=$OID_NORTEL_rcVlanPortDefaultVlanId
	elif [ $3 == "Alcatel" ]
	then
		OID=$OID_ALCATEL_VLAN_ID
		return
	else
		return
	fi
	unset table_access_vlans

	for i in `$WALK -On -v2c -c $2 $1  $OID` 
	do
		ifindex=`echo $i |awk '{print $1}' | awk -F"." '{print $NF}' `
		v=`echo $i | awk '{print $NF}' `
		table_access_vlans[$ifindex]=$v
	done 
}
