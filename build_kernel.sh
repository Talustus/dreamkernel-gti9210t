#!/bin/bash
#
# Colors for error/info messages
#
TXTRED='\e[0;31m' 		# Red
TXTGRN='\e[0;32m' 		# Green
TXTYLW='\e[0;33m' 		# Yellow
BLDRED='\e[1;31m' 		# Red-Bold
BLDGRN='\e[1;32m' 		# Green-Bold
BLDYLW='\e[1;33m' 		# Yellow-Bold
TXTCLR='\e[0m'    		# Text Reset
#
## Settings
#

## Create TAR File for ODIN?
ODIN_TAR=yes		# yes/no

## Create ZIP File for CWM? (needs a updater-template.zip in releasedir)
CWM_ZIP=yes		# yes/no

##
## Directory Settings
##
export KERNELDIR=`readlink -f .`
export TOOLBIN="${KERNELDIR}/../bin"
export INITRAMFS_SOURCE="${KERNELDIR}/../initramfs"
export INITRAMFS_TMP="/tmp/initramfs-gti9210t"
export RELEASEDIR="${KERNELDIR}/../releases"

# get time of startup
time_start=$(date +%s.%N)

# InitRamFS Branch to use ...
# export RAMFSBRANCH=cm10-testing

# Build Hostname
export KBUILD_BUILD_HOST=`hostname | sed 's|deblap|vs117.dream-irc.com|g'`

#
# Version of this Build
#
KRNRLS="DreamKernel-GTI9210T-v1.8.6CM10"


#
# Target Settings
#
export ARCH=arm
# export CROSS_COMPILE=$WORK_DIR/../cyano-dream/system/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-
export CROSS_COMPILE=/home/talustus/arm-gti9210t-androideabi/bin/galaxys2-
export USE_SEC_FIPS_MODE=true

if [ "${1}" != "" ];
then
  if [ -d  $1 ];
  then
    export KERNELDIR=`readlink -f ${1}`
    echo -e "${TXTGRN}Using alternative Kernel Directory: ${KERNELDIR}${TXTCLR}"
  else
    echo -e "${BLDRED}Error: ${1} is not a directory !${TXTCLR}"
    echo -e "${BLDRED}Nothing todo, Exiting ... !${TXTCLR}"
    # finished? get elapsed time
    time_end=$(date +%s.%N)
    echo "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_start - $time_end) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
    exit 1
  fi
fi

if [ ! -f $KERNELDIR/.config ];
then
  echo -e "${TXTYLW}Kernel config does not exists, creating default config (dream_gti9210t_defconfig):${TXTCLR}"
  make ARCH=arm dream_gti9210t_defconfig  2>&1 | grcat conf.gcc
  echo -e "${TXTYLW}Kernel config created ...${TXTCLR}"
fi

. $KERNELDIR/.config

# remove Files of old/previous Builds
#
echo -e "${TXTYLW}Deleting Files of previous Builds ...${TXTCLR}"
make -j2 clean 2>&1 | grcat conf.gcc
# echo "0" > $KERNELDIR/.version

# Remove Old initramfs
echo -e "${TXTYLW}Deleting old InitRAMFS${TXTCLR}"
rm -rf $INITRAMFS_TMP
rm -rf $INITRAMFS_TMP.*

# Clean Up old Buildlogs
# echo -e "${TXTYLW}Deleting old logfiles${TXTCLR}"
# rm -v $KERNELDIR/compile-*.log

# Remove previous Kernelfiles
echo -e "${TXTYLW}Deleting old Kernelfiles${TXTCLR}"
rm $KERNELDIR/arch/arm/boot/kernel
rm $KERNELDIR/arch/arm/boot/zImage
rm $KERNELDIR/boot.img


# Start the Build
#
echo -e "${TXTYLW}CleanUP done, starting kernel Build ...${TXTCLR}"

nice -n 10 make -j2 modules 2>&1 | grcat conf.gcc
# nice -n 10 make -j12 KBUILD_BUILD_HOST="$KBUILD_BUILD_HOST" modules 2>&1 | tee compile-modules.log || exit 1
#
if [ "$?" == "0" ];
then
  echo -e "${TXTYLW}Modules Build done ...${TXTCLR}"
  sleep 2
else
  echo -e "${BLDRED}Modules Build failed, exiting  ...${TXTCLR}"
    # finished? get elapsed time
    time_end=$(date +%s.%N)
    echo "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_start - $time_end) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
  exit 1
fi

echo -e "${TXTGRN}Build: Stage 1 successfully completed${TXTCLR}"

# copy initramfs files to tmp directory
#
echo -e "${TXTGRN}Copying initramfs Filesystem to: ${INITRAMFS_TMP}${TXTCLR}"
cd $INITRAMFS_SOURCE
# git checkout $RAMFSBRANCH
cd $KERNELDIR
cp -vax $INITRAMFS_SOURCE $INITRAMFS_TMP
sleep 1

# remove repository realated files
#
echo -e "${TXTGRN}Deleting Repository related Files (.git, .hg etc)${TXTCLR}"
find $INITRAMFS_TMP -name .git -exec rm -rf {} \;
find $INITRAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;
rm -rf $INITRAMFS_TMP/.hg

# copy modules into initramfs
#
echo -e "${TXTGRN}Copying Modules to initramfs: ${INITRAMFS_TMP}/lib/modules${TXTCLR}"

mkdir -pv $INITRAMFS_TMP/lib/modules
find $KERNELDIR -name '*.ko' -exec cp -av {} $INITRAMFS_TMP/lib/modules/ \;
sleep 1

echo -e "${TXTGRN}Striping Modules to save space${TXTCLR}"
${CROSS_COMPILE}strip --strip-unneeded $INITRAMFS_TMP/lib/modules/*
sleep 1

# create the initramfs cpio archive
#
$TOOLBIN/mkbootfs $INITRAMFS_TMP > $INITRAMFS_TMP.cpio
echo -e "${TXTGRN}Unpacked Initramfs: $(ls -lh $INITRAMFS_TMP.cpio)${TXTCLR}"

# Create gziped initramfs
#
echo -e "${TXTGRN}compressing InitRamfs...${TXTCLR}"
$TOOLBIN/minigzip < $INITRAMFS_TMP.cpio > $INITRAMFS_TMP.img
echo -e "${TXTGRN}Final gzip compressed Initramfs: $(ls -lh $INITRAMFS_TMP.img)${TXTCLR}"

### 2nd way of ramfs creation
#cd $INITRAMFS_TMP
#find | fakeroot cpio -H newc -o > $INITRAMFS_TMP.cpio 2>/dev/null
#echo -e "${TXTGRN}Unpacked Initramfs: $(ls -lh $INITRAMFS_TMP.cpio)${TXTCLR}"
#echo -e "${TXTGRN}compressing InitRamfs...${TXTCLR}"
#gzip -9 $INITRAMFS_TMP.cpio
#echo -e "${TXTGRN}Packed Initramfs: $(ls -lh $INITRAMFS_TMP.img)${TXTCLR}"
sleep 1

#cd -

# Start Final Kernel Build
#
echo -e "${TXTYLW}Starting final Build: Stage 2${TXTCLR}"
nice -n 10 make -j2 zImage 2>&1 | grcat conf.gcc

if [ -f  $KERNELDIR/arch/arm/boot/zImage ];
then
  echo " "
  echo -e "${TXTGRN}Final Build: Stage 3. Creating bootimage !${TXTCLR}"
  echo " "
  sleep 1
  cp -v $KERNELDIR/arch/arm/boot/zImage $KERNELDIR/arch/arm/boot/kernel

  $TOOLBIN/mkbootimg --kernel $KERNELDIR/arch/arm/boot/kernel --ramdisk $INITRAMFS_TMP.img --cmdline "androidboot.hardware=qcom msm_watchdog.appsbark=0 msm_watchdog.enable=1 init=/sbin/init console=/dev/console" --base 0x40400000 --pagesize 2048 --ramdiskaddr 0x41800000 --output $KERNELDIR/boot.img
  # $TOOLBIN/mkbootimg --kernel $KERNELOUT/arch/arm/boot/kernel --ramdisk $WORK_DIR/ramdisk.img --cmdline "androidboot.hardware=qcom msm_watchdog.appsbark=0 msm_watchdog.enable=1 no_console_suspend=true" --base 0x40400000 --pagesize 2048 --ramdiskaddr 0x41800000 --output $KERNELOUT/boot.img

  if [ -f $KERNELDIR/boot.img ];
  then
    echo " "
    echo -e "${TXTGRN}Final Build: Stage 3 completed successfully!${TXTCLR}"
    echo " "
    rm $KERNELDIR/arch/arm/boot/kernel

    # Archive Name for ODIN/CWM archives
    ARCNAME="$KRNRLS-`date +%Y%m%d%H%M%S`"

    ## Create ODIN Flashable TAR archiv ?
    if [ "${ODIN_TAR}" == "yes" ];
    then
      echo -e "${BLDRED}creating ODIN-Flashable TAR: ${ARCNAME}${TXTCLR}"
      cd $KERNELDIR
      tar cf $RELEASEDIR/$ARCNAME.tar boot.img
      echo -e "${BLDRED}$(ls -lh ${RELEASEDIR}/${ARCNAME}.tar)${TXTCLR}"
    else
      echo -e "${BLDRED}Skipping ODIN-TAR creation${TXTCLR}"
      echo "   "
    fi

    ## Check for update template
    if [ ! -f $RELEASEDIR/updater-template.zip ];
    then
      CWM_ZIP=no
    fi

    ## Create CWM-ZIP ?
    if [ "${CWM_ZIP}" == "yes" ];
    then
      echo -e "${BLDRED}creating CWM-Flashable ZIP: ${ARCNAME}-CWM.zip${TXTCLR}"
      cp $RELEASEDIR/updater-template.zip $RELEASEDIR/$ARCNAME-CWM.zip
      zip -u $RELEASEDIR/$ARCNAME-CWM.zip boot.img
      ls -lh $RELEASEDIR/$ARCNAME-CWM.zip
      echo -e "${BLDRED}$(ls -lh ${RELEASEDIR}/${ARCNAME}-CWM.zip)${TXTCLR}"
      echo -e "  "
    else
      echo -e "${BLDRED}Skipping CWM-ZIP creation${TXTCLR}"
      echo "  "
    fi
    echo "  "
    echo -e "${BLDGRN}	#############################	${TXTCLR}"
    echo -e "${TXTRED}	# Script completed, exiting #	${TXTCLR}"
    echo -e "${BLDGRN}	#############################	${TXTCLR}"
    echo " "
    # finished? get elapsed time
    time_end=$(date +%s.%N)
    echo "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
    exit 0
  else
    echo " "
    echo -e "${BLDRED}Final Build: Stage 3 failed with Error!${TXTCLR}"
    echo -e "${BLDRED}failed to build Boot Image, exiting ...${TXTCLR}"
    echo " "
    # finished? get elapsed time
    time_end=$(date +%s.%N)
    echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
    exit 1
  fi
else
  echo " "
  echo -e "${BLDRED}Final Build: Stage 2 failed with Error!${TXTCLR}"
  echo -e "${BLDRED}failed to compile Kernel Image, exiting ...${TXTCLR}"
  echo " "
  time_end=$(date +%s.%N)
  echo "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_start - $time_end) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
  exit 1
fi
