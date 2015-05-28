#!/bin/sh
# A simple script to shrink a image of unwanted free space.

# This is a Beerware release
# If you like it, Buy your Buddy a Beer
# If not, recycle it nicely so it may R.I.P.

# Have A Great Day
# ShorTie  <ShorTie@idiot.com>

if [ ! "$1" ]; then
  echo "Usage: ./Image_shrinker.sh <file_name>"
  exit 1
fi
IMAGEFILE="$1"

echo "Checking for root"
if [ $(id -u) -ne 0 ]; then
  echo "Script must be run as root"
  exit 1
fi

echo " "
echo "Checking for a 3rd partition"
THIRD_PART=$(fdisk -l $IMAGEFILE | grep 'img3' |  awk '{print $2}')
if [ "$THIRD_PART" != ""  ]; then
  echo " "
  echo "So, So, Sorry .. :(~"
  echo "This script only works on the standard"
  echo "  2 partition systems"
  exit 1
fi

echo " "
echo "Checking for enough free space"
echo "These numbers are in 1K blocks"
FREE_SPACE=$(df | grep 'rootfs' | awk '{print $4}')
printf "Free space "
echo $FREE_SPACE
printf "File size  "
FILE_SIZE=$(ls -s $IMAGEFILE | awk '{print $1}')
echo $FILE_SIZE
echo " "
if [ "$FILE_SIZE" -gt "$FREE_SPACE" ]; then
  echo "So, So, Sorry .. :)~"
  echo "You do not have enough free space to unpack the image."
  echo "Maybe try running 'apt-get clean' and try again"
  exit 1
else
  echo "L00ks like you have enough free space .. :)~"
  echo "Lets go for it...."
fi

echo " "
echo "A desktop image needs more free space,"
echo " to be able to boot into the desktop."
echo "Is this a desktop image ??  <Y/n>"
read resp
if [ "$resp" = "n" ]; then
  FUDGE_FACTOR=4194304
else
  FUDGE_FACTOR=524288000
fi

echo " "
echo "Specifics of the image file"
fdisk -l $IMAGEFILE

echo " "
echo " "
echo "Finding the starting Block of the 2nd partition "
PARTITION_START=$(fdisk -l $IMAGEFILE | grep 'img2' | awk '{print $2}')

if [ ! "$PARTITION_START" ]; then
  printf "Failed to extract root partition offset\n"
  exit 1
fi
printf "Starting Block is "
echo $PARTITION_START
printf "Sector size "
SECTOR_SIZE=$(fdisk -l $IMAGEFILE | grep 'Units' | awk '{print $9}')
echo $SECTOR_SIZE

START_BLOCK_4K=$(($PARTITION_START/4))
printf "4K Starting Block size "
echo $START_BLOCK_4K

echo " "
echo "Figuring out the 2nd partition starting byte"
PARTITION_START_BYTES=$(($PARTITION_START * $SECTOR_SIZE))
printf "Partition starting byte "
echo $PARTITION_START_BYTES

echo " "
echo "Requesting a new free loopback device"
LOOP_DEV=$(losetup -f)
printf "loopback device is "
echo $LOOP_DEV

echo " "
echo "Extracting 2nd partition of image to the loopback device"
losetup --offset "$PARTITION_START_BYTES" $LOOP_DEV "$IMAGEFILE"

echo " "
echo "Sanity check on $LOOP_DEV"
file -s $LOOP_DEV

echo " "
echo "Listing superblocks of $LOOP_DEV"
dumpe2fs $LOOP_DEV | grep -i superblock

echo " "
echo "Forced file system check of $LOOP_DEV"
e2fsck -f $LOOP_DEV

echo " "
echo "Resizing filesystem to the minimum size of $LOOP_DEV"
echo "This can take awhile..."
resize2fs -pM $LOOP_DEV

echo " "
echo "Long directory listing of Image file"
ls -l $IMAGEFILE

echo " "
echo "Figuring out some specifics"

BLOCK_COUNT=$(tune2fs -l /dev/loop0 | grep "^Block count" | cut -d ":" -f 2 | tr -d ' ')
printf "Block count "
echo $BLOCK_COUNT

BLOCK_SIZE=$(tune2fs -l /dev/loop0 | grep "^Block size" | cut -d ":" -f 2 | tr -d ' ')
printf "Block size "
echo $BLOCK_SIZE

FREE_BLOCKS=$(tune2fs -l /dev/loop0 | grep "^Free blocks" | cut -d ":" -f 2 | tr -d ' ')
printf "Free blocks "
echo $FREE_BLOCKS

FILE_SYSTEM_BYTES=$(($BLOCK_COUNT * $BLOCK_SIZE))
printf "File system bytes "
echo $FILE_SYSTEM_BYTES

echo " "
echo "Listing superblocks of $LOOP_DEV"
dumpe2fs $LOOP_DEV | grep -i superblock

echo " "
echo "Unmountting $LOOP_DEV"
losetup -d $LOOP_DEV

echo " "
echo "Calculating new image size in bytes "
NEW_IMG_BYTES=$(($FILE_SYSTEM_BYTES + $PARTITION_START_BYTES + $FUDGE_FACTOR))
echo $NEW_IMG_BYTES

echo " "
echo "Calculating 2nd partition end"
PARTITION_END=$(($PARTITION_START + ($NEW_IMG_BYTES / $SECTOR_SIZE)))

echo " "
echo "Extracting image to $LOOP_DEV to resize partition"
losetup -v $LOOP_DEV "$IMAGEFILE"

echo " "
echo "Resizing partition"
fdisk $LOOP_DEV <<EOF
p
d
2
n
p
2
$PARTITION_START
$PARTITION_END
p
w
EOF

echo " "
echo "Run partprobe on ${LOOP_DEV} so new size takes effect"
partprobe ${LOOP_DEV}

echo " "
echo "Unmount it all"
losetup -d $LOOP_DEV

echo " "
echo "Truncating image to new size"
truncate --size=$NEW_IMG_BYTES $IMAGEFILE

echo " "
echo "Create a device of the image"
losetup --offset "$PARTITION_START_BYTES" -v $LOOP_DEV "$IMAGEFILE"

echo " "
echo "Resizing file system full size of image"
resize2fs ${LOOP_DEV}

echo " "
echo "Sanity check"
file -s $LOOP_DEV

echo " "
echo "Checking Integrity"
e2fsck -pf ${LOOP_DEV}

echo " "
echo "Listing superblocks"
dumpe2fs $LOOP_DEV | grep -i superblock

losetup -d $LOOP_DEV

FINAL_FILE_SIZE=$(ls -s $IMAGEFILE | awk '{print $1}')
DIFF=$(($FILE_SIZE - $FINAL_FILE_SIZE))

echo " "
echo "L@@ks like it worked"
echo "Atleast we made it to the end, lol."
#printf "We shrunk the image by "
#echo $DIFF
echo "Have A Great Day"
echo "ShorTie       <ShorTie@idiot.com>"
