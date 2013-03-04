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
NOW=$(date +"%Y-%m-%d_%Hh%Mm%Ss")
RSYNCOPTIONS="-rtv"
VERBOSE=1
# No changes below this line


function DidItFail {
  [ $? -ne 0 ] && echo "Failed: $1" && exit $?
  [ $VERBOSE -ne 0 ] && echo "$1  [OK!]"
}

function MyCloneCreate {
  zfs create $SOURCEPOOL/myclone
  DidItFail "zfs create $SOURCEPOOL/myclone"
  for t in ${DATASETS[@]}
  do
    zfs snapshot $SOURCEPOOL/$t@rsync
    DidItFail "zfs snapshot $SOURCEPOOL/$t@rsync"
    zfs clone $SOURCEPOOL/$t@rsync $SOURCEPOOL/myclone/$t
    DidItFail "zfs clone $SOURCEPOOL/$t@rsync $SOURCEPOOL/myclone/$t"
  done
}

function MyCloneDestroy {
  for t in ${DATASETS[@]}
  do
    zfs destroy $SOURCEPOOL/myclone/$t
    DidItFail "zfs destroy $SOURCEPOOL/myclone/$t"
    zfs destroy $SOURCEPOOL/$t@rsync
    DidItFail "zfs destroy $SOURCEPOOL/$t@rsync"
  done
  zfs destroy $SOURCEPOOL/myclone
  DidItFail "zfs destroy $SOURCEPOOL/myclone"
}

cd $MYMOUNTPOINT

[ "$1" ] && DRYRUN="--dry-run"
[ "$1" == "-q" ] && RSYNCOPTIONS="-rt" && VERBOSE=0 && DRYRUN=""

[ $VERBOSE -ne 0 ] && echo "Looking for $TARGETPOOL please wait."

[ ! "$(zpool list -H | egrep -w "^${TARGETPOOL}" | awk '{print $1}')" ] && zpool import $TARGETPOOL 2>/dev/null && DidItFail "zpool import $TARGETPOOL"
[ ! "$(zpool list -H | egrep -w "^${TARGETPOOL}" | awk '{print $1}')" ] && echo "zpool \"${TARGETPOOL}\" not found!" && exit 1
[ ! -d $MYMOUNTPOINT/$TARGETPOOL ] && mkdir $MYMOUNTPOINT/$TARGETPOOL && DidItFail "mkdir $MYMOUNTPOINT/$TARGETPOOL"

[ `stat -nq -f %d "$TARGETPOOL"` == `stat -nq -f %d "$TARGETPOOL/.."` ] && \
    zfs set mountpoint=$MYMOUNTPOINT/$TARGETPOOL $TARGETPOOL && \
    DidItFail "zfs set mountpoint=$MYMOUNTPOINT/$TARGETPOOL $TARGETPOOL"

MyCloneCreate

rsync $RSYNCOPTIONS --delete $DRYRUN $SOURCEPOOL/myclone/ $TARGETPOOL
DidItFail "Rsync finished"

MyCloneDestroy

zfs snapshot $TARGETPOOL@$NOW
DidItFail "zfs snapshot $TARGETPOOL@$NOW"

zfs set mountpoint=/mnt/MyBackup $TARGETPOOL
DidItFail "zfs set mountpoint=/mnt/MyBackup $TARGETPOOL"

zpool export $TARGETPOOL
DidItFail "zpool export $TARGETPOOL"

exit 0

