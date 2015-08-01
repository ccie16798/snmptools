#! /bin/sh



IFS=$(echo -en "\n\b")

##get_ip_ports2 file_port file_macs file_arps
#file_port format : hostname;port;admin_status;oper_status;desc
#file_macs format : hostname;port;mac;vlan
#file_arp  format : hostname;mac;ip

for j in `cat $1 | grep -v "^##"` 
do
	host=`echo  $j|awk -F";" '{print $1}' `
	port=`echo  $j|awk -F";" '{print $2}' `
	if_a=`echo  $j|awk -F";" '{print $3}' `
	if_o=`echo  $j|awk -F";" '{print $4}' `
	alias=`echo $j|awk -F";" '{print $5}' `


	macs=`cat $2|grep "$host;$port;"`
	# il faut absolument mettre le ; apres $port sinon le port G1/1 matcherait G1/1, G1/12, G1/13 etc...
#	echo EEEEE $host $port $macs
	a=0
	for m in ${macs[*]}
	do
		mac=`echo $m|awk -F";" '{print $3}' `
		if [ -z $mac ]
		then 
			echo "BUG : pas de mac trouvee dans $m liste ${macs[*]}"
			exit 1
		fi
		ip=`grep $mac $3 | awk -F";" '{print $3}'| head -1`
		if [ -z $ip ]
		then 
			ip=NA
		fi
		echo -e "$host\t$port\t$if_a\t$if_o\t$mac\t$ip\t$alias"
		((a=$a+1))
	done
	if (($a <= 0)) 
	then
		echo -e "$host\t$port\t$if_a\t$if_o\tNA\tNA\t$alias"
	fi

done

exit 0
