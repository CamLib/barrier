#!/bin/bash
#
# Entrance barrier barcode scanning script
#
# Tristram Scott
# 03/06/2014

# The log file is written as three colon-separated fields.  The first is empty, except
# for the line stating the software started, when it is the date as mm_dd.
# The second is a count of people who have entered.
# The third is the time, followed by the user name and a comment to say they entered, 
# they were refused entry, or they did not enter.

barrierdir=${0%/*}
numbersfile=${barrierdir}/NUMBERS.CUR
today=`date "+%d%m%Y"`
logfile=${barrierdir}/${today}.LOG
shortday=`date "+%m_%d"`
# The serial port
COM1=/dev/ttyS0


#
# checkstatus  Check the current status of the relays
#
checkstatus() {
	echo '$026' > $COM1
	getresponse
}

#
# getresponse  Get response from relays
#
getresponse() {
	read -t 1 LINE < $COM1
	r=$?
	if [ $r -eq 0 ] ; then
		echo "Response is $LINE" 
	else
		echo "No response received.  Don't mind."
	fi
}

#
# ignoreresponse  Get response from relays, but discard it.
#
ignoreresponse() {
	read -t 1 LINE < $COM1
}

#
# openbarrier
#
openbarrier () {
	echo "Closing relay contacts"
	echo '#021001' > $COM1
	ignoreresponse
	checkstatus
	echo "Sleeping for 1 second"
	sleep 1
	echo "Opening relay contacts"
	echo '#021000' > $COM1
	ignoreresponse
	checkstatus
	echo "Finished in openbarrier"
}


echo "Using log file of $logfile"
echo "Credentials are in $numbersfile"

echo "Checking status of relays..."
checkstatus
echo "Done checking relay status."

touch ${logfile}

lastcount=$(($(grep -v started $logfile | tail -1  | cut -f 2 -d:)))

echo "Last count is $lastcount"
now=`date "+%H:%M:%S"`
printf "%s : %s : PC Program started.\r\n" $shortday $now >> $logfile
printf ":%5s : %s\r\n" $lastcount "$now User 'ZZZZZ' entered." >> $logfile

echo "Ready to read barcode."
while true; do
	read -n 6  -t5 LINE
	r=$?
#	echo "Line was $LINE, of length ${#LINE}"
	if [ $r -eq 0 ] ; then
		if [ ${#LINE} -eq 5 ] ; then
			now=`date "+%H:%M:%S"` ;
			lastcount=$(($(grep -v started $logfile | tail -1  | cut -f 2 -d:)))
			nextcount=$(($(grep -v started $logfile | tail -1  | cut -f 2 -d:)+1)) ;
			BARCODE=`echo $LINE | tr '[:lower:]' '[:upper:]'`
			grep  -q $BARCODE $numbersfile
			r=$?
			if [ $r -eq 0 ] ; then
				printf "++++ Found user %s.  Allow entry. ++++\n" $BARCODE 
				openbarrier
			    printf ":%5s : %s\r\n" $nextcount "$now User '$BARCODE' entered." >> $logfile ;
			elif [ $BARCODE == "VZZZZ" ] ; then
				printf "++++ Special user %s.  Allow entry. ++++\n" $BARCODE 
				openbarrier
			    printf ":%5s : %s\r\n" $nextcount "$now User '$BARCODE' entered." >> $logfile ;
			else
				printf "XXXXXXX   Did not find user %s. \a\a  Refuse entry.   XXXXXXX\n" $BARCODE 
		    	printf ":%5s : %s\r\n" $lastcount "$now User '$BARCODE' refused entry." >> $logfile ;
			fi
			lastcount=$(($(grep -v started $logfile | tail -1  | cut -f 2 -d:)))
			printf "Last count is %s.\n\nReady to read barcode.\n" $lastcount
	else
			echo "Expected 5 charcters, but $LINE is ${#LINE}."
		fi
	fi		
done
