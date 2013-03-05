#!/bin/bash

# zfs-geek-backup v0.02

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

# Change these variables to suit your configuration
SOURCEPOOL=My320POOL
DATASETS=('data' 'photo')


# These variables should work as is
MYMOUNTPOINT=/mnt
TARGETPOOL=MyBackup
NOW=$(date +"%Y-%m-%d_%Hh%Mm%Ss")
RSYNCOPTIONS="-rtv"
VERBOSE=1


# No changes below this line
# ====================================================

function TEMPzfsGEEKdatasetCleanup {
  zfs list -H -o name -t filesystem | grep TEMPzfsGEEKdataset/ | xargs -n1 zfs destroy
  zfs list -H -o name -t filesystem | grep TEMPzfsGEEKdataset | xargs -n1 zfs destroy
  MyEcho "$? - zfs destroy -r $SOURCEPOOL/TEMPzfsGEEKdataset"
  zfs list -H -o name -t snapshot | grep TEMPzfsGEEKsnapshot | xargs -n1 zfs destroy
  MyEcho "$? - zfs destroy TEMPzfsGEEKsnapshot"
}

function TEMPzfsGEEKdatasetCreate {
  zfs create $SOURCEPOOL/TEMPzfsGEEKdataset
  MyEcho "$? - zfs create $SOURCEPOOL/TEMPzfsGEEKdataset"
  for t in ${DATASETS[@]}
  do
    zfs snapshot $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot
    test "$?" -ne "0" && echo "Failed: zfs snapshot $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot" && exit 1
    MyEcho "$? - zfs snapshot $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot"
    zfs clone $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot $SOURCEPOOL/TEMPzfsGEEKdataset/$t
    test "$?" -ne "0" && echo "Failed: zfs clone $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot $SOURCEPOOL/TEMPzfsGEEKdataset/$t" && exit 1
    MyEcho "$? - zfs clone $SOURCEPOOL/$t@TEMPzfsGEEKsnapshot $SOURCEPOOL/TEMPzfsGEEKdataset/$t"
  done
}

function MyEcho {
  test "$VERBOSE" -gt "0" && echo "$1"
}

cd $MYMOUNTPOINT

[ "$1" == "--dry-run" ] && DRYRUN="--dry-run"
[ "$1" == "-q" ] && RSYNCOPTIONS="-rt" && VERBOSE=0 && DRYRUN=""


MyEcho "================"
MyEcho "zfs-geek-backup"
MyEcho "================"
MyEcho ""
MyEcho "Cleanup. Just in case the previous backup crashed and left a mess."
TEMPzfsGEEKdatasetCleanup
MyEcho ""
MyEcho "Looking for $TARGETPOOL please wait..."
MyEcho ""

[ ! "$(zpool list -H | egrep -w "^${TARGETPOOL}" | awk '{print $1}')" ] && zpool import $TARGETPOOL 2>/dev/null && MyEcho "$? - zpool import $TARGETPOOL"
[ ! "$(zpool list -H | egrep -w "^${TARGETPOOL}" | awk '{print $1}')" ] && echo "Failed: zpool import $TARGETPOOL" && exit 1
[ ! -d $MYMOUNTPOINT/$TARGETPOOL ] && mkdir $MYMOUNTPOINT/$TARGETPOOL && MyEcho "$? - mkdir $MYMOUNTPOINT/$TARGETPOOL"

[ `stat -nq -f %d "$TARGETPOOL"` == `stat -nq -f %d "$TARGETPOOL/.."` ] && \
    zfs set mountpoint=$MYMOUNTPOINT/$TARGETPOOL $TARGETPOOL && \
    MyEcho "$? - zfs set mountpoint=$MYMOUNTPOINT/$TARGETPOOL $TARGETPOOL"

TEMPzfsGEEKdatasetCreate

MyEcho ""
MyEcho ""
MyEcho "rsync $RSYNCOPTIONS --delete $DRYRUN $SOURCEPOOL/TEMPzfsGEEKdataset/ $TARGETPOOL"
rsync $RSYNCOPTIONS --delete $DRYRUN $SOURCEPOOL/TEMPzfsGEEKdataset/ $TARGETPOOL
MyEcho ""
MyEcho ""

zfs snapshot $TARGETPOOL@$NOW
MyEcho "$? - zfs snapshot $TARGETPOOL@$NOW"

TEMPzfsGEEKdatasetCleanup

zfs set mountpoint=/mnt/$TARGETPOOL $TARGETPOOL
MyEcho "$? - zfs set mountpoint=/mnt/$TARGETPOOL $TARGETPOOL"

zpool export $TARGETPOOL
MyEcho "$? - zpool export $TARGETPOOL"

MyEcho ""
exit 0
