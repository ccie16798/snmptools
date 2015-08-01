#! /bin/sh



ARP_OID=.1.3.6.1.2.1.4.22.1.2


function get_hostname () {
 local truc=`snmpget  -On -v2c -c $2 $1  1.3.6.1.2.1.1.5.0 2> /dev/null `
 # si snmpget se choppe un timeout on repond un "" chaine vide quoi
 echo $truc| awk '{print $NF'} 2> /dev/null
}

function get_arp() {
	local i

	for i in `snmpwalk -On -v2c -c $2 $1 .1.3.6.1.2.1.4.22.1.2`
	do	
		# printf a la con car la MAC est au format compact
		mac=`echo $i | awk '{print $NF}' | awk -F":" '{printf("%02s:%02s:%02s:%02s:%02s:%02s", $(NF-5),$(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF)}' `
		ip=`echo $i | awk '{print $1}' | awk -F "." '{printf("%d.%d.%d.%d",$(NF-3),$(NF-2),$(NF-1),$NF)}' `
		echo "$mhouost;$mac;$ip"
	done
}

IFS=$(echo -en "\n\b")

if (($# <= 1 ))
then
        echo "auriez vous la bonte de me donner la liste de routeur"
        echo $0 file @fichier_sw_list
        echo $0 single @ip @com
        exit 1
fi
if [ $1 == single ]
then
	mhouost=`get_hostname $2 $3`
	get_arp $2 $3

elif [ $1 == file ]
	then


	swlist=$2
	for entry in `cat $swlist`
	do
        # switch 
        	s=`echo $entry| awk -F"--" '{print $2}'`
        # communaute
        	com=`echo $entry| awk -F"--" '{print $3}'`


        	mhouost=`get_hostname $s $com`
        	if [ -z $mhouost ]
        	then
                	echo "$s repond pas"
                	continue
        	fi
        	get_arp $s $com
	done
else
	echo "$0 file|single args"
fi
