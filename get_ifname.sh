#! /bin/sh



for i in `cat sw-test`
do
        sw=`echo $i | awk -F"--" '{print $2}' `
        com=`echo $i | awk -F"--" '{print $3}' `
	snmpwalk -v2c -c $com $sw IF-MIB::ifDescr
	snmpwalk -v2c -c $com $sw IF-MIB::ifName
done
