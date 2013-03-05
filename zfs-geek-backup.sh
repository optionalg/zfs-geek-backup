#!/bin/bash

# zfs-geek-backup v0.01

: '===============================================================
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/
=================================================================='

# Edit these variables to suit your setup
MYMOUNTPOINT=/mnt
TARGETPOOL=MyBackup
SOURCEPOOL=My320POOL
DATASETS=('data' 'photo')
# No changes below this line

NOW=$(date +"%Y-%m-%d_%Hh%Mm%Ss")
RSYNCOPTIONS="-rtv"
VERBOSE=1

function TEMPzfsGEEKbackupCleanup {
  zfs list -H -o name -t filesystem | grep TEMPzfsGEEKbackup/ | xargs -n1 zfs destroy
  zfs list -H -o name -t filesystem | grep TEMPzfsGEEKbackup | xargs -n1 zfs destroy
  echo "$? - zfs destroy -r $SOURCEPOOL/TEMPzfsGEEKbackup"
  zfs list -H -o name -t snapshot | grep TEMPzfsGEEKsnapshot | xargs -n1 zfs destroy
  echo "$? - zfs destroy TEMPzfsGEEKsnapshot"
}

function TEMPzfsGEEKbackupCreate {
  zfs create $SOURCEPOOL/TEMPzfsGEEKbackup
  echo "$? - zfs create $SOURCEPOOL/TEMPzfsGEEKbackup"
  for t in ${DATASETS[@]}
  do
    zfs snapshot $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot
    echo "$? - zfs snapshot $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot"
    zfs clone $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot $SOURCEPOOL/TEMPzfsGEEKbackup/$t
    echo "$? - zfs clone $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot $SOURCEPOOL/TEMPzfsGEEKbackup/$t"
  done
}

cd $MYMOUNTPOINT
echo ""

[ "$1" ] && DRYRUN="--dry-run"
[ "$1" == "-q" ] && RSYNCOPTIONS="-rt" && VERBOSE=0 && DRYRUN=""


TEMPzfsGEEKbackupCleanup
 

echo ""
[ $VERBOSE -ne 0 ] && echo "Looking for $TARGETPOOL please wait."
echo ""

[ ! "$(zpool list -H | egrep -w "^${TARGETPOOL}" | awk '{print $1}')" ] && zpool import $TARGETPOOL 2>/dev/null && echo "$? - zpool import $TARGETPOOL"
[ ! "$(zpool list -H | egrep -w "^${TARGETPOOL}" | awk '{print $1}')" ] && echo "zpool \"${TARGETPOOL}\" not found!" && exit 1
[ ! -d $MYMOUNTPOINT/$TARGETPOOL ] && mkdir $MYMOUNTPOINT/$TARGETPOOL && echo "$? - mkdir $MYMOUNTPOINT/$TARGETPOOL"

[ `stat -nq -f %d "$TARGETPOOL"` == `stat -nq -f %d "$TARGETPOOL/.."` ] && \
    zfs set mountpoint=$MYMOUNTPOINT/$TARGETPOOL $TARGETPOOL && \
    echo "$? - zfs set mountpoint=$MYMOUNTPOINT/$TARGETPOOL $TARGETPOOL"

TEMPzfsGEEKbackupCreate

echo ""
echo ""
echo "Running Rsync..."
rsync $RSYNCOPTIONS --delete $DRYRUN $SOURCEPOOL/TEMPzfsGEEKbackup/ $TARGETPOOL
echo ""
echo ""

zfs snapshot $TARGETPOOL@$NOW
echo "$? - zfs snapshot $TARGETPOOL@$NOW"

TEMPzfsGEEKbackupCleanup

zfs set mountpoint=/mnt/MyBackup $TARGETPOOL
echo "$? - zfs set mountpoint=/mnt/MyBackup $TARGETPOOL"

zpool export $TARGETPOOL
echo "$? - zpool export $TARGETPOOL"

echo ""
exit 0