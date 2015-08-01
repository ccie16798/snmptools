#! /bin/sh

IFS=$(echo -en "\n\b")


table_os_string=("Nortel|Business Policy Switch|BayStack|Avaya|Ethernet Routing Switch" "Passport|ERS-8610" "ERS-16" "Cisco" "alcatel")
table_os=("Nortel" "Passport" "ERS-16XX" "Cisco" "Alcatel")


function get_os2 () {
	local i
	local a 
	local b
	local c
	local z
	
	a=`snmpget -Ov -v2c -c $2 $1 SNMPv2-MIB::sysDescr.0`
        b=`snmpget -Ov -v2c -c $2 $1 SNMPv2-MIB::sysContact.0`
        c=$a$b

	for i in ${!table_os[*]}
	do
		os_string=${table_os_string[$i]}
		z=`echo $c | egrep -i $os_string`
		if (( ${#z} > 2 ))
		then
			echo "${table_os[$i]}"
			return
		fi
	done
	echo "Unknown"
}



function is_nortel() {
	local z

	z=`echo $1 | egrep -i "Nortel| Passport"` 
	if (( ${#z} > 2 ))
	then
		echo YES
	else
		echo NO
	fi
}
function is_cisco() {
	local z

	z=`echo $1 | grep -i Cisco` 
	if (( ${#z} > 2 ))
	then
		echo YES
	else
		echo NO
	fi
}
function is_alcatel() {
	local z

	z=`echo $1 | grep -i alcatel` 
	if (( ${#z} > 2 ))
	then
		echo YES
	else
		echo NO
	fi
}

function get_os() {
	a=`snmpget -Ov -v2c -c $2 $1 SNMPv2-MIB::sysDescr.0`
        b=`snmpget -Ov -v2c -c $2 $1 SNMPv2-MIB::sysContact.0`
        c=$a$b
	if [ `is_nortel $c` == YES ]
	then
		echo Nortel
	elif [ `is_cisco $c` == YES ]
	then
		echo Cisco
	elif [ `is_alcatel $c` == YES ]
	then
		echo Alcatel
	else
		echo Unknown
	fi
}

for i in `cat sw-test`
do
	sw=`echo $i | awk -F"--" '{print $2}' `
	com=`echo $i | awk -F"--" '{print $3}' `
	
	a=`snmpget -Ov -v2c -c $com $sw SNMPv2-MIB::sysDescr.0`
	b=`snmpget -Ov -v2c -c $com $sw SNMPv2-MIB::sysContact.0`
	c=$a$b
	get_os $sw $com
	get_os2 $sw $com
	

done
