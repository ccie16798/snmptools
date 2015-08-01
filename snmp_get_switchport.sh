#! /bin/bash
# C Mahmoud Basset
# v04/03/2013 


if [ ! -f ./lib_snmp.sh ]
then
	echo "fichier lib_snmp.h introuvable"
	exit 1
fi
. lib_snmp.sh
IFS=$(echo -en "\n\b")


function print_one_line () {
	local i
	local type

	i=$1
	type=${table_switchport[$i]}
	if [ -z $type ]
        then
		echo "$mhouost;\"${table_ifDescr[$i]}\";NA;;"
	elif [ $type == "1" ]
	then
		echo "$mhouost;\"${table_ifDescr[$i]}\";TRUNK;\"${table_trunk_vlans[$i]}\""
	elif [ $type == "2" ]
	then
		echo "$mhouost;\"${table_ifDescr[$i]}\";ACCESS;\"${table_access_vlans[$i]}\""
	else
		echo "$mhouost;\"${table_ifDescr[$i]}\";NA;;"
	fi
}

function test_all_switch() {
	local i
	local j
	local sw
	local com

	for j in `cat $1`
	do
		sw=`echo $j | awk -F"--" '{print $2}' `
		com=`echo $j | awk -F"--" '{print $3}' `

		mhouost=`get_hostname  $sw $com`
		if [ -z $mhouost ]
		then
			continue
		fi
		os=`get_os $sw $com`
		get_ifname $sw $com $os
		get_switchport_status $sw $com $os
		get_trunk_vlans $sw $com $os
		get_access_vlans $sw $com $os

		for i in ${!table_switchport[*]}
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
		if [ -z $mhouost ]
		then
			echo $1 [communaute $2] ne repond pas
			exit 1
		fi
		os=`get_os $2 $3`
		get_ifname $2 $3 $os
		get_switchport_status $2 $3 $os
		get_trunk_vlans $2 $3 $os
		get_access_vlans $2 $3 $os

		for i in ${!table_switchport[*]}; do
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
        echo "$0 [single|file]  @opt "
        echo si mode == single, @opt = @IP @COM
        echo si mode == file , @opt = file_name
	exit 1
fi
main $1 $2 $3
