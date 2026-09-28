#!/bin/bash
userid=`whoami`
host=`hostname`
sessionPID=`ps -u ${userid} -o user:12,pid,ppid,stime,cmd | /usr/bin/grep cas | grep -v grep | awk '{print $2}'`
masterPID=`ps -u cas -o user:12,pid,ppid,stime,cmd | grep "cas join" | awk '{print $2}'`
buffcache=`free -m | grep Mem | awk '{print $6}'`
casdisk=`df -m /cas | grep -v Used | awk '{print $3}'`

echo
echo "*********************************"
echo "*** CAS_DISK_CACHE Monitoring ***"
echo "*********************************"
echo
echo Your userid: ${userid}
echo Your CAS session PID on ${host}: ${sessionPID}
echo "The master CAS session PID (owner is cas):" ${masterPID}
echo

echo
echo "*** Buffer Cache used (MB) ***"
echo
echo ${buffcache}

echo
echo "*** /cas (CAS_DISK_CACHE location) used (MB) ***"
echo
echo ${casdisk}

echo
echo "*** Session CAS tables: files in CAS_DISK_CACHE ***"
echo
lsof -a +L1 -p ${sessionPID} | grep _${sessionPID}_

echo
echo "*** Session CAS tables: # files in CAS_DISK_CACHE ***"
echo
lsof -a +L1 -p ${sessionPID} | grep _${sessionPID}_ | wc -l

echo
echo "*** Global CAS tables created in this CAS session: files in CAS_DISK_CACHE ***"
echo
sudo -u cas lsof -a +L1 -p ${masterPID} | grep _${sessionPID}_

echo
echo "*** Global CAS tables created in this CAS session: # files in CAS_DISK_CACHE ***"
echo
sudo -u cas lsof -a +L1 -p ${masterPID} | grep _${sessionPID}_ | wc -l

# echo
# echo "***Try this if you want a real-time view of CAS_DISK_CACHE file: lsof -a +L1 -p ${sessionPID} -r1"
# echo
