#! /bin/sh



TRUC="00 01 00 50 00 51 00 53 00 54 00 55 00 56 00 57 00 58 00 59 00 5A 00 5B 00 5F 00 60 00 62 00 63 00 64 00 65 00 67 00 6A 00 6B 00 6D 00 6E 00 6F 00 70 00 73 00 75 00 76 00 77 00 78 00 79 00 7A 01 F4"

c=0

for j in $TRUC
do
	if (($c%2 == 0))
	then
		i=0x$j
	else
		vlan=$((8*$i + 0x$j))
		echo $vlan
	fi
	c=$(($c+1))
	
done 

