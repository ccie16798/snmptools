#! /bin/bash
# C Mahmoud Basset
# v13/11/2012 


if [ ! -f ./lib_snmp.sh ]
then
	echo "fichier lib_snmp.h introuvable"
	exit 1
fi
. lib_snmp.sh
IFS=$(echo -en "\n\b")


function print_one_line () {
	local i
	
	i=$1
	type=${table_switchport[$i]}
	desc=${table_ifDescr[$i]}
	a_status=${table_ifAdminStatus[$i]}
	o_status=${table_ifOperStatus[$i]}
	alias=${table_ifAlias[$i]}
	speed=${table_ifSpeed[$i]}
	if [ -z $type ]
	then
		echo "$mhouost;$desc;$a_status;$o_status;$alias;$speed;NA;NA"
	elif [ $type == "1" ]
	then
		echo "$mhouost;$desc;$a_status;$o_status;$alias;$speed;TRUNK;${table_trunk_vlans[$i]}"
	elif [ $type == "2" ]
	then
		echo "$mhouost;$desc;$a_status;$o_status;$alias;$speed;ACCESS;${table_access_vlans[$i]}"
	else
		echo "$mhouost;$desc;$a_status;$o_status;$alias;$speed;NA;NA"
	fi
}

function test_all_switch() {
	local i
	local sw
	local com

	for j in `cat $1|grep -v "^#"`
	do
		sw=`echo $j | awk -F"--" '{print $2}' `
		com=`echo $j | awk -F"--" '{print $3}' `

		mhouost=`get_hostname  $sw $com`
		if [ -z $mhouost ]
		then
			continue
		fi
		#il faut resetter les tableaux sinon aie
		unset table_ifAdminStatus
		unset table_ifOperStatus
		unset table_ifindex
	
		os=`get_os $sw $com`
		get_ifname $sw $com $os
		get_ifType $sw $com
		get_ifAlias $sw $com
		get_ifAdminStatus $sw $com
		get_ifOperStatus $sw $com
		get_ifSpeed $sw $com
		get_switchport_status $sw $com $os
		get_trunk_vlans $sw $com $os
		get_access_vlans $sw $com $os

		for i in ${!table_ifOperStatus[*]}
		do
			print_one_line $i
		done		
	done
}


function main() {
	local i

	if [ $1 == "single" ]
	then
		mhouost=`get_hostname  $2 $3`
		echo $mhouost
		if [ -z $mhouost ]
		then
			echo $1 [communaute $2] ne repond pas
		exit 1
		fi
		os=`get_os $sw $com`
		get_ifname $2 $3 $os > /dev/null
		get_ifType $2 $3  
		get_ifAdminStatus $2 $3
		get_ifOperStatus $2 $3
		get_switchport_status $2 $3 $os
		get_trunk_vlans $2 $3 $os
		get_access_vlans $2 $3 $os

		for i in ${!table_ifOperStatus[*]}
		do
			print_one_line $i
		done		
	elif [ $1 == "file" ]
	then
		test_all_switch $2
	else
		echo "$O [single|file] @opts"
	fi

}


if (($# < 2 ))
then
        echo "$0 [single|file]  @opt"
        echo "si mode == single, @opt = @IP @COM"
        echo "si mode == file , @opt = file_name"
	exit 1

fi
main $1 $2 $3
