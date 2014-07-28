#!/bin/bash
#
# Samsung Galaxy S2 LTE - GT-i9210(T)
# Kernel buildscript for 'DreamKernel'
#
# please make sure to change needed lines to fit your build env
# script needs to be in the same directory as the actual Kernel Source !
#

## Colors for shell error/info messages
#
TXTRED='\e[0;31m' 		# Red
TXTGRN='\e[0;32m' 		# Green
TXTYLW='\e[0;33m' 		# Yellow
BLDRED='\e[1;31m' 		# Red-Bold
BLDGRN='\e[1;32m' 		# Green-Bold
BLDYLW='\e[1;33m' 		# Yellow-Bold
TXTCLR='\e[0m'    		# Text Reset

## Settings
#
# Version of this Build
#
## got up to 3.0 for CM10.2
KRNRLS="DreamKernel-GTI9210T-LiquidTest_2"

# Build Hostname
export KBUILD_BUILD_HOST=`hostname | sed 's|boris|build001.AU.dream-irc.com|g'`

## Create TAR File for ODIN?
ODIN_TAR=no			# yes/no

## Create ZIP File for CWM? (needs a updater-template.zip in releasedir)
CWM_ZIP=yes			# yes/no

## Directory Settings
#
export KERNELDIR=`readlink -f .`
export TOOLBIN="${KERNELDIR}/../../bin"
export INITRAMFS_SOURCE="${KERNELDIR}/../initramfs-liquid"
export INITRAMFS_TMP="/tmp/initramfs-liquid"
export RELEASEDIR="${KERNELDIR}/../releases"
export DREAM_DEFCONF=liquid_i9210t_defconfig
export USE_CCACHE=1

# get time of startup
time_start=$(date +%s.%N)

# InitRamFS Branch to use ...
# export RAMFSBRANCH=cm-10.2

# Target Settings
#
export ARCH=arm
export USE_SEC_FIPS_MODE=true


## Toolchain
export TOOL_CHAIN="galaxys4-"

# Choose Propper Compiler setup
if [ "${USE_CCACHE}" == "1" ];
then
  echo -e "${TXTGRN}Using ccache Compiler Cache ..${TXTCLR}"
  export CCACHE_DIR="${KERNELDIR}/../../.ccache"
  export CROSS_COMPILE="ccache ${TOOL_CHAIN}"
else
  echo -e "${TXTYLW}NOT using ccache Compiler Cache ..${TXTCLR}"
  export CROSS_COMPILE="${TOOL_CHAIN}"
fi

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
    echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
    exit 1
  fi
fi

# remove Files of old/previous Builds
#
echo -e " "
echo -e "${TXTYLW}Deleting old Kernel / Boot Images${TXTCLR}"
echo -e " "

[ -f $KERNELDIR/boot.img ] && echo -e "${BLDYLW}$(rm -v ${KERNELDIR}/boot.img)${TXTCLR}"
[ -f $KERNELDIR/arch/arm/boot/kernel ] && echo -e "${BLDYLW}$(rm -v ${KERNELDIR}/arch/arm/boot/kernel)${TXTCLR}"
[ -f $KERNELDIR/arch/arm/boot/zImage ] && echo -e "${BLDYLW}$(rm -v ${KERNELDIR}/arch/arm/boot/zImage)${TXTCLR}"

# Remove Old initramfs
echo -e " "
echo -e "${TXTYLW}Deleting old InitRAMFS${TXTCLR}"
rm -rf $INITRAMFS_TMP
rm -rf $INITRAMFS_TMP.*

# for testing etc u may want to comment this?
#
echo -e "${TXTYLW}Deleting Files of previous Builds ...${TXTCLR}"
make -j4 distclean 2>&1 | ${TOOLBIN}/grcat conf.gcc

if [ ! -f $KERNELDIR/.config ];
then
  if [ ! -f $KERNELDIR/arch/arm/configs/$DREAM_DEFCONF ];
  then
    clear
    # finished? get elapsed time
    time_end=$(date +%s.%N)
    echo -e "  "
    echo -e "${BLDRED}(-ERROR-): can not find default Kernel Config: ${DREAM_DEFCONF} !${TXTCLR}"
    echo -e "${BLDRED}this is a critical error, Exiting ... !${TXTCLR}"
    echo -e "  "
    echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
    echo -e "  "
    exit 1
  fi
  echo -e " "
  echo -e "${TXTYLW}Creating Kernel config from default: ${DREAM_DEFCONF} ${TXTCLR}"
  make ARCH=arm ${DREAM_DEFCONF} 2>&1 | ${TOOLBIN}/grcat conf.gcc
  echo -e "${TXTYLW}Kernel config created ...${TXTCLR}"
  echo -e " "
fi

## Source the kernel config
. $KERNELDIR/.config

# Start Kernel (zImage) Build
#
echo -e "${TXTYLW}(-INFO-): Starting build of zImage${TXTCLR}"
nice -n 10 make -j4 zImage 2>&1 | ${TOOLBIN}/grcat conf.gcc

# Check for error
if [ "$?" == "0" ];
then
  echo -e " "
  echo -e "${TXTYLW}(-INFO-): Kernel Build done ...${TXTCLR}"
  sleep 1
else
  # finished? get elapsed time
  time_end=$(date +%s.%N)
  echo -e " "
  echo -e "${BLDRED}(-Error-): Kernel Build failed, exiting  ...${TXTCLR}"
  echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
  exit 1
fi

# Check for zImage
if [ -f  $KERNELDIR/arch/arm/boot/zImage ];
then
  cp $KERNELDIR/arch/arm/boot/zImage $KERNELDIR/arch/arm/boot/kernel
  sleep 1
else
  echo " "
  echo -e "${BLDRED}(-ERROR-): can not find kernel image (zImage), build failed?${TXTCLR}"
  echo " "
  time_end=$(date +%s.%N)
  echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
  exit 1
fi

# Start the modules Build
#
echo -e " "
echo -e "${TXTYLW}(-INFO-): Building Kernel modules ...${TXTCLR}"
echo -e " "
nice -n 10 make -j4 modules 2>&1 | ${TOOLBIN}/grcat conf.gcc

## Check for Error
if [ "$?" == "0" ];
then
  echo -e " "
  echo -e "${TXTYLW}(-INFO-): Modules Build done ...${TXTCLR}"
  sleep 2
else
  echo -e " "
  echo -e "${BLDRED}(-ERROR-): failed to build Kernel modules, exiting  ...${TXTCLR}"
  # finished? get elapsed time
  time_end=$(date +%s.%N)
  echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
  exit 1
fi

echo -e " "
echo -e "${TXTGRN}(-INFO-): Kernel compile finished, creating initramfs ...${TXTCLR}"
echo -e " "

# copy initramfs files to tmp directory
#
echo -e " "
echo -e "${TXTGRN}(-INFO-): Copying initramfs Filesystem to: ${INITRAMFS_TMP}${TXTCLR}"
echo -e " "
cd $INITRAMFS_SOURCE
# git checkout $RAMFSBRANCH
cd $KERNELDIR
echo -e "${TXTYLW}$(cp -vax ${INITRAMFS_SOURCE} ${INITRAMFS_TMP})${TXTCLR}"
sleep 1

## remove repository realated files
#
echo -e " "
echo -e "${TXTGRN}Deleting Repository related Files (.git, .hg etc)${TXTCLR}"
echo -e "${TXTYLW}$(find $INITRAMFS_TMP -name .git -exec rm -rf {} \;)${TXTCLR}"
echo -e "${TXTYLW}$(find $INITRAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;)${TXTCLR}"
rm -rf $INITRAMFS_TMP/.hg

## copy modules into initramfs
#
echo -e " "
echo -e "${TXTGRN}(-INFO-): Copying Modules to initramfs: ${INITRAMFS_TMP}/lib/modules${TXTCLR}"
echo -e " "

echo -e "${TXTYLW}$(mkdir -pv ${INITRAMFS_TMP}/lib/modules)${TXTCLR}"
echo -e "${TXTYLW}$(find ${KERNELDIR} -name '*.ko' -exec cp -av {} ${INITRAMFS_TMP}/lib/modules/ \;)${TXTCLR}"
sleep 1

echo -e "${TXTGRN}(-INFO-): Striping Modules to save space${TXTCLR}"
echo -e " "
echo -e "${TXTYLW}$(${TOOL_CHAIN}strip --strip-unneeded ${INITRAMFS_TMP}/lib/modules/*)${TXTCLR}"
echo -e " "
sleep 1

## create the initramfs cpio archive
#
$TOOLBIN/mkbootfs $INITRAMFS_TMP > $INITRAMFS_TMP.cpio
echo -e " "
echo -e "${TXTGRN}(-INFO-): Unpacked Initramfs: $(ls -lh $INITRAMFS_TMP.cpio)${TXTCLR}"
echo -e " "

## Create gziped initramfs
#
echo -e "${TXTGRN}(-INFO-): compressing InitRamfs...${TXTCLR}"
$TOOLBIN/minigzip < $INITRAMFS_TMP.cpio > $INITRAMFS_TMP.img
echo -e "${TXTGRN}(-INFO-): Final gzip compressed Initramfs: $(ls -lh $INITRAMFS_TMP.img)${TXTCLR}"
sleep 2
echo -e " "
echo -e "${TXTGRN}(-INFO-): finished building INITRAMFS${TXTCLR}"
echo -e "${TXTGRN}(-INFO-): creating final Boot Image${TXTCLR}"

## Commandline specific for Galaxy S2 LTE GT-I9210T, dont change
$TOOLBIN/mkbootimg --kernel $KERNELDIR/arch/arm/boot/kernel --ramdisk $INITRAMFS_TMP.img --cmdline "androidboot.hardware=qcom usb_id_pin_rework=true no_console_suspend=true zcache init=/sbin/init" --base 0x40400000 --pagesize 2048 --ramdisk_offset 0x01400000 --output $KERNELDIR/boot.img

if [ -f $KERNELDIR/boot.img ];
then
  echo " "
  echo -e "${TXTGRN}(-INFO-): successfully created boot.img!${TXTCLR}"
  echo " "
  # rm $KERNELDIR/arch/arm/boot/kernel
  # rm $KERNELDIR/arch/arm/boot/zImage

  ## Archive Name for ODIN/CWM archives
  ARCNAME="$KRNRLS-`date +%Y%m%d%H%M%S`"

  ## Create ODIN Flashable TAR archiv ?
  if [ "${ODIN_TAR}" == "yes" ];
  then
    echo -e " "
    echo -e "${BLDRED}(-INFO-): creating ODIN-Flashable TAR: ${ARCNAME}${TXTCLR}"
    cd $KERNELDIR
    tar cf $RELEASEDIR/$ARCNAME.tar boot.img
    echo -e "${BLDGRN}$(ls -lh ${RELEASEDIR}/${ARCNAME}.tar | awk '{ printf "Tar: "$8"\n" "Size: "$5"\n" }')${TXTCLR}"
  else
    echo -e " "
    echo -e "${BLDRED}(-INFO-): Skipping ODIN-TAR creation${TXTCLR}"
    echo "   "
  fi
  
  ## Check for update template
  if [ ! -f $RELEASEDIR/updater-template.zip ];
  then
    CWM_ZIP=no
    echo -e "${BLDRED}(-INFO-): Updater Template not found!${TXTCLR}"
    echo "  "
  fi

  ## Create CWM-ZIP ?
  if [ "${CWM_ZIP}" == "yes" ];
  then
    echo -e "${BLDRED}(-INFO-): creating CWM-Flashable ZIP: ${ARCNAME}-CWM.zip${TXTCLR}"
    cp $RELEASEDIR/updater-template.zip $RELEASEDIR/$ARCNAME-CWM.zip
    echo -e "${BLDGRN}$(zip -u ${RELEASEDIR}/${ARCNAME}-CWM.zip boot.img)${TXTCLR}"
    echo -e " "
    echo -e "${BLDGRN}$(ls -lh ${RELEASEDIR}/${ARCNAME}-CWM.zip | awk '{ printf "Zip: "$8"\n" "Size: "$5"\n" }')${TXTCLR}"
    echo -e "  "
  else
    echo -e "${BLDRED}(-INFO-): Skipping CWM-ZIP creation${TXTCLR}"
    echo "  "
  fi
  ## finished? get elapsed time
  time_end=$(date +%s.%N)
  echo "  "
  echo -e "${BLDGRN}	#############################	${TXTCLR}"
  echo -e "${TXTRED}	# Script completed, exiting #	${TXTCLR}"
  echo -e "${BLDGRN}	#############################	${TXTCLR}"
  echo " "
  echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
  exit 0
else
  # finished? get elapsed time
  time_end=$(date +%s.%N)
  echo " "
  echo -e "${BLDRED}(-ERROR-): failed to build Boot Image, exiting ...${TXTCLR}"
  echo " "
  echo -e "${BLDYLW}Total time elapsed: ${TCTCLR}${TXTGRN}$(echo "($time_end - $time_start) / 60"|bc ) ${TXTYLW}minutes${TXTGRN} ($(echo "$time_end - $time_start"|bc ) ${TXTYLW}seconds) ${TXTCLR}"
  exit 1
fi
