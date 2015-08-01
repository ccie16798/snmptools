#! /bin/bash
# C Mahmoud Basset
# v04/03/2013 

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
		os=`get_os $sw $com`
		get_vlans $sw $com $os
		get_vlans_name $sw $com $os

		for v in ${vlans[*]}; do
			echo "$mhouost;$v;${vlans_name[$v]}"
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
		get_vlans $2 $3 $os
		get_vlans_name $2 $3 $os

		for v in ${!vlans[*]}; do
			echo "$mhouost;${vlans[$v]};${vlans_name[$v]}"
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
