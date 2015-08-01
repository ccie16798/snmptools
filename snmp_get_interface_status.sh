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


function test_all_switch() {
	local c
	local i
	local j
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

		for i in ${!table_ifOperStatus[*]}
		do
			echo "$mhouost;${table_ifDescr[$i]};${table_ifAdminStatus[$i]};${table_ifOperStatus[$i]};${table_ifAlias[$i]};${table_ifSpeed[$i]}"
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
		os=`get_os $2 $3`
		get_ifname $2 $3 $os
		get_ifType $2 $3  
		get_ifAdminStatus $2 $3
		get_ifOperStatus $2 $3

		for i in ${!table_ifOperStatus[*]}
		do
			echo "$mhouost;${table_ifDescr[$i]};${table_ifAdminStatus[$i]};${table_ifOperStatus[$i]};${table_ifAlias[$i]}"
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
