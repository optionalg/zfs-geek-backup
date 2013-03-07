# Using Rsync and ZFS snapshots... #
zfs-geek-backup can do incremental backups to removable drives, each backup drive is a full image plus snapshots.

## My setup ##

- [Hard drive dock](http://www.google.ca/search?q=hard+drive+dock)
- Assortment of hard drives, new or used
- [NAS4Free](http://www.nas4free.org/ "NAS4Free")

## Instructions ##

### I have a basic NAS4Free system with one ZFS pool

	pool:	My320POOL
	state:	ONLINE
	scan:	scrub repaired 0 in 1h12m with 0 errors on Fri Mar  1 12:09:30 2013
	config:
	My320POOL			ONLINE	0	0	0
	mirror-0ONLINE				0	0	0
	ada1ONLINE					0	0	0
	ada0ONLINE					0	0	0
	errors: No known data errors

### I have created several datasets ###

	NAME					  USED	   AVAIL	REFER	MOUNTPOINT
	My320POOL				  184G		110G	44.5K	/mnt/My320POOL
	My320POOL/data			 1.48G		110G	1.47G	/mnt/My320POOL/data
	My320POOL/install		 11.1G		110G	11.1G	/mnt/My320POOL/install
	My320POOL/music			 7.62G		110G	7.62G	/mnt/My320POOL/music
	My320POOL/photo			 14.5G		110G	14.5G	/mnt/My320POOL/photo
	My320POOL/video			149.0G		110G	 149G	/mnt/My320POOL/video

### To use zfs-geek-backup with a similar setup follow these steps ###

1. Attach the external drive and create a pool named **zfsgeekbackup**
1. Copy zfs-geek-backup.sh and open it for editing.
2. Edit the pool and dataset variables `SOURCEPOOL=My320POOL` and `DATASETS=('data' 'photo')`
3. Save and execute the script


### You may run the backup at anytime ###

    ./zfs-geek-backup.sh //not so quiet
    ./zfs-geek-backup.sh -q  //quiet, only errors will output
    ./zfs-geek-backup.sh --dry-run  //adds --dry-run to the rsync commandline

### Overview - What happens? ###

- You plug in one of the backup drives and your system sees it as a device but ZFS ignores it. You, or cron, run the backup script.
- It imports the zfsgeekbackup pool
- It creates a temporary dataset named TEMPzfsGEEKbackup
- It makes temporary snapshots of your selected datasets eg: DATASETS=('data' 'photo')
- It makes a temporary clone under TEMPzfsGEEKbackup of each snapshot eg: TEMPzfsGEEKbackup/photo
- It Rsyncs the incremental changes from TEMPzfsGEEKbackup to zfsgeekbackup
- It destroys the clones that it created
- It destroys the TEMPzfsGEEKbackup dataset that it created
- It destroys the temporary snapshots that it created
- It creates a snapshot on zfsgeekbackup eg: zfsgeekbackup@2013-03-05_01h52m48s
- It exports the zfsgeekbackup pool

You may now swap the backup drive and take it off site.

## Tips ##

### See what you have on a backup drive ###
    
    zpool import zfsgeekbackup
    zfs list -H -o name -t snapshot | grep zfsgeekbackup
    ls /mnt/zfsgeekbackup/.zfs/snapshot
    zpool export zfsgeekbackup
        
### Get rid of all snapshots on zfsgeekbackup ### 
    
    zpool import zfsgeekbackup
    zfs list -H -o name -t snapshot | grep zfsgeekbackup | xargs -n1 zfs destroy
    zpool export zfsgeekbackup
    
### Get a clean start on an existing zfsgeekbackup drive ###
    
    zpool import zfsgeekbackup
    zpool destroy zfsgeekbackup
    zpool create zfsgeekbackup da1
    zpool export zfsgeekbackup
    
### Add another drive to your collection of backup drives ###
    
    zpool create zfsgeekbackup da1
    zpool export zfsgeekbackup
      
### It's da1 on my machine but will likely be something different on yours ###
Immediately after you insert a drive into the dock your system should see it and spit out some messages like these below. Using the `dmesg | tail` command I can see that my drive is at da1. So... `zpool create zfsgeekbackup da1` be **careful** now.
    
    	nas4free# dmesg | tail
    	da1 at umass-sim1 bus 1 scbus9 target 0 lun 0
    	da1: WDC WD50 03ABYX-01WERA0 Fixed Direct Access SCSI-2 device
    	da1: 40.000MB/s transfers
    	da1: 476940MB (976773168 512 byte sectors: 255H 63S/T 60801C)
    	nas4free#_
    

