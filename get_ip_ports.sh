#! /bin/sh



IFS=$(echo -en "\n\b")


# le fait uniquement pour les ports 
# derriere lesquels il y a mac
# 

for i in `cat $1 | grep -v "^##"` 
do
	host=`echo $i|awk '{print $1}' `
	port=`echo $i|awk '{print $2}' `
	mac=`echo $i|awk '{print $5}' `
	if [ -z $mac ]
	then 
		continue
	fi
	alias=`echo $i|awk -F"//" '{print $2}' `

	ip=`grep $mac $2 | awk '{print $3}'| head -1`
	echo $host $port $mac $ip [$alias]
done
