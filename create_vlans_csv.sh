#! /bin/sh


IFS=$(echo -en "\n\b")

# les vlans sont stockes dans un fichier sous le format
# HOSTNAME;VLAN_ID;VLAN_NAME

# cherchons les vlans dans chaque switchs

hostid=VOID
c=0

if (($# <= 0 ))
then
	echo "$0 filename"
	echo "filename est au format : HOSTAME;VLAN_ID;VLAN_NAME"
	exit 1
fi

for i in `cat $1`; do
	v_id=`echo $i | awk -F";"  '{print $2}'`
	h=`echo $i | awk -F";"  '{print $1}'`

	if [ $h != $hostid ]
	then
		table_hosts[$c]=$h
		((c=$c+1))
		hostid=$h
	fi
	vlans[$v_id]=$v_id

done

echo -ne "VLAN"
for h in ${table_hosts[*]}
do
	echo -ne ";$h"
done
echo -ne "\n"

#pour chaque vlan
for v in ${!vlans[*]}; do
	echo -ne "$v;"
	
	#recherchons dans pour chaque host si le vlan est present et quel nom il a 
	for h in ${table_hosts[*]}
	do
		i=`egrep "$h;$v;" $1`
		if  (( ${#i} < 2 ))
		then
			echo -ne "NA;"
		else
			j=`echo -ne $i | awk -F";" '{print $3}'`
			echo -ne "$j;"
		fi
	done
	echo -ne "\n"
done

