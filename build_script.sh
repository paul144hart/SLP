#Build Script for  preparing  the Colibri-V50 BSP #
#Supporting V2.4 / VF50 environment
# Directory structure:
# -SLPvf50
#	-linux-bsp >> uboot and linux
#	-toolchain >> compiler
#	-tslib >> multi touch libs
#	-qt-source >> qmake, libs, etc for Qt4
#	-patches >> tars, devicetree files, copies for rootfs
#	-ubifs >> local image of RFS and assorted files
#!/bin/bash

ARCH=arm
HOST=arm-linux-gnueabihf
ROOT_FS=rootfs
BUILD_DIR=${HOME}/SLPvf50
TFTP_ROOT=/tftpboot

PATCH_DIR=${HOME}/SLPvf50/patches

#*****************ROOT-FS **************************
COLIBRI_IMAGE=Colibri_VF_LinuxImageV2.5_20151215.tar.bz2
TORADEX_TOOLS=Colibri_VF_LinuxImageV2.5
UBIFS_DIR=${BUILD_DIR}/ubifs
MINIMAL_FS_TYPE=Angstrom-core-image-minimal-glibc-ipk-v2014.12-colibri-vf.rootfs.tar.bz2
MINIMAL_FS_ROOT=${HOME}/oe-core/build/out-glibc/deploy/images/colibri-vf
OPENEMBEDDED_FS=$MINIMAL_FS_ROOT/${MINIMAL_FS_TYPE}
ROOTFS_ROOT=$UBIFS_DIR/rootfs	
CONFIG=${PATCH_DIR}/etc/config
SYSTEMD=$PATCH_DIR/etc/systemd
NETWORK=${SYSTEMD}/network
MULTILINE_TARGET=${SYSTEMD}/system/multi-user.target.wants


INIT_DIR=rootfs/home/root/Init
OUTPUT_DIR=$HOME/SLPvf50/patches/setra_build
LIB_DIR=$HOME/SLPvf50/patches/setra_build/libs
BIN_DIR=$HOME/SLPvf50/patches/setra_build/bin




compile_bacnet()
{
    echo "$0:$LINENO: start of compiling BACnet stack" 			| tee -a ~/$0.log
    cd ${UBIFS_DIR}
    echo "$0:$LINENO: Remove mstp.ko before building next one"          | tee -a ~/$0.log
    sudo rm $PATCH_DIR/MSTP/mstp.ko
    ls -al  $PATCH_DIR/MSTP
    cd ~/QtProjects/slpdrivers/BACNet/StackLib/
#    make clean
    echo "$0:$LINENO: ***Make cross bacnet mstp"                        | tee -a ~/$0.log
    make cross_bacnetmstp
    echo "$0:$LINENO: ***Make cross bacnet ip"                          | tee -a ~/$0.log
    make cross_bacnetip
    echo "$0:$LINENO: ***Make cross bacnet router"                      | tee -a ~/$0.log
    make cross_bacnetrtr
    echo "$0:$LINENO: ***Make mstp.ko"                                  | tee -a ~/$0.log
    cd mstp
    make clean
    make CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm
    echo "$0:$LINENO: end of compiling BACnet stack" 			| tee -a ~/$0.log

}


###################################################################
prep_image()
{
   cd ${UBIFS_DIR}
   pwd 							                | tee -a ~/$0.log
   echo "$0:$LINENO: Patch is " $PATCH_DIR				| tee -a ~/$0.log
   ls $PATCH_DIR/multi_touch_bin/bin                                    | tee -a ~/$0.log
   sudo cp -apr $PATCH_DIR/multi_touch_bin/bin/mtdev2tuio rootfs/usr/bin 
   sudo chmod 777 rootfs/usr/bin/mtdev2tuio 
   sudo cp -apr $PATCH_DIR/etc/configs/ts.conf rootfs/etc/ 
   sudo cp -apr $PATCH_DIR/etc/systemd/system/multi-user.target.wants/startup.service \
         rootfs/etc/systemd/system/multi-user.target.wants
   sudo cp -apr $PATCH_DIR/busybox  rootfs/bin/busybox.nosuid 
   sudo rm rootfs/home/root/mstp.ko  #delete the pre-existing one in case we tried to compile and failed
   sudo cp -apr $PATCH_DIR/MSTP/mstp.ko rootfs/home/root/ 
   sudo cp -apr $PATCH_DIR/application_libs/* rootfs/usr/lib/
#   sudo cp -apr $PATCH_DIR/ConfigureInterface.txt rootfs/home/root/ 
   sudo cp -apr $PATCH_DIR/configs/pointercal rootfs/etc/pointercal
#disable telnet
#   sudo ln -sf /bin/busybox       rootfs/usr/sbin/telnetd
if [ -f "rootfs/usr/sbin/telnetd" ]; then
      sudo rm  rootfs/usr/sbin/telnetd
fi

#disable ntp
if [ -f "rootfs/lib/systemd/systemd-timesyncd" ]; then
   sudo rm rootfs/lib/systemd/systemd-timesyncd
fi

   cd ${UBIFS_DIR}
   echo "$0:$LINENO:Deleting Existing Libraries ......" 		| tee -a ~/$0.log
   pwd 							| tee -a ~/$0.log
   sudo rm -rf  rootfs/usr/lib/libBackLight.so* 
   sudo rm -rf  rootfs/usr/lib/libBACNet.so* 
   sudo rm -rf  rootfs/usr/lib/libEthernet.so* 
   sudo rm -rf  rootfs/usr/lib/libHWComm.so* 
   sudo rm -rf  rootfs/usr/lib/libIOComm.so*
   sudo rm -rf  rootfs/usr/lib/libLog.so*
   sudo rm -rf  rootfs/usr/lib/libUsbUpgrade.so* 
   sudo rm -rf  rootfs/usr/lib/libqpcap.so* 

   echo "$0:$LINENO:Copying Latest Selected Libraries ......" 	| tee -a ~/$0.log
   pwd 							| tee -a ~/$0.log
   echo "$0:$LINENO:lib source is $LIB_DIR"                     | tee -a ~/$0.log
   echo "$0:$LINENO:bin source is $BIN_DIR"                     | tee -a ~/$0.log
   echo "$0:$LINENO:build dir source is $OUTPUT_DIR"                     | tee -a ~/$0.log

   sudo cp -apr ${LIB_DIR}/* rootfs/usr/lib 
   sudo cp -apr ${BIN_DIR}/* rootfs/home/root 
   echo "$0:$LINENO:Copying Latest Selected Init ......"   | tee -a ~/$0.log
   if [ ! -d "rootfs/home/root/Init" ]; then
      sudo mkdir rootfs/home/root/Init
   fi
   sudo rm rootfs/home/root/Init/*	
   sudo cp -apr $OUTPUT_DIR/Init/* rootfs/home/root/Init 
   sudo rm rootfs/home/root/*sh
   sudo cp -apr $PATCH_DIR/scripts/*sh rootfs/home/root 
   sudo chown -R root:root * 
   sudo rm -rf rootfs/lib/systemd/system/getty@.service
}

INIT_DIR=rootfs/home/root/Init
###################################################################
flash_image()
{
   echo "start of flashing image" 			| tee -a ~/$0.log
   prep_image
   zenity --info --text="Please Insert the USB/USB Card Reader and select the corresponding /dev Node entry!!!!!!! .... "
   cd /dev #head start on picking a usb drive
   REMOVABLE_USB_MEDIA=$(zenity --file-selection)	
   if [[ $REMOVABLE_USB_MEDIA = *"sda"* ]]; then
        echo "Fool, that's the main drive!"
	exit
   fi
   zenity --question --title="USB DEVICE " \
    --text="are you sure that ${REMOVABLE_USB_MEDIA} is  USB drive/USB card reader "
	if [ $? = 0 ]; then	
	zenity --info --text="Selected Media $REMOVABLE_USB_MEDIA"
	cd ${UBIFS_DIR} 
        pwd | tee -a ~/$0.log
	ls -al | tee -a ~/$0.log
        pwd | tee -a ~/$0.log
	echo "$0:$LINENO: - changing owner to root"
	sudo chown -R root:root *

	sudo cp ~/SLPvf50/ubifs/colibri-vf_bin/ubifs.img /srv/tftp/colibri_vf
	echo "$0:$LINENO: calling format_sd.h"
	./format_sd.sh -d  $REMOVABLE_USB_MEDIA
	fi
   cd ${UBIFS_DIR} #in case if above is not evaluated!
   sudo chown -R $USER:$USER *
   echo "$0:$LINENO:end of flash_image" | tee -a ~/$0.log
}

#####################################################################
prep_tftp()
{
	prep_image
	cd ~/SLPvf50/ubifs
	sudo chown -R root:root *
	./update.sh -o /srv/tftp
	#sudo chown -R setra:setra *
	cd /srv/tftp
	sudo chown -R nobody *

}
#******************QT-LIBRARIES**************************#
QT_SRC_VER=qt-everywhere-opensource-src-4.8.6
QT_SOURCE=${BUILD_DIR}/qt-source
QT_OUTLIB=$QT_SOURCE/output

compile_qt_source () {	
	echo "$0:$LINENO:compiling qt source files" | tee -a ~/$0.log
	
	cd $QT_SOURCE

	cd $QT_SRC_VER
	make distclean 2>&1 | tee -a ~/$0.log

	sed -i -e 's/arm-none-linux-gnueabi/arm-linux-gnueabihf/g'  mkspecs/qws/linux-arm-gnueabi-g++/qmake.conf 2>&1 | tee -a ~/$0.log

	sed -i "15i QMAKE_INCDIR 	+= ${MULTITOUCH_OUT_DIR}/include" mkspecs/qws/linux-arm-gnueabi-g++/qmake.conf 2>&1 | tee -a ~/$0.log
	sed -i "16i QMAKE_LIBDIR	+= ${MULTITOUCH_OUT_DIR}/lib"     mkspecs/qws/linux-arm-gnueabi-g++/qmake.conf 2>&1 | tee -a ~/$0.log
	sed -i "17i QMAKE_LFLAGS	+= -Wl,-rpath-link=${MULTITOUCH_OUT_DIR}/lib" mkspecs/qws/linux-arm-gnueabi-g++/qmake.conf 2>&1 | tee -a ~/$0.log

	echo  "QMAKE_INCDIR 	+= ${MULTITOUCH_OUT_DIR}/include" >>  mkspecs/qws/linux-arm-gnueabi-g++/qmake.conf
	echo  "QMAKE_LIBDIR	+=${MULTITOUCH_OUT_DIR}/lib"      >> mkspecs/qws/linux-arm-gnueabi-g++/qmake.conf
	echo "load(qt_config)" 					  >> mkspecs/qws/linux-arm-gnueabi-g++/qmake.conf 

	./configure -embedded arm -xplatform qws/linux-arm-gnueabi-g++ -prefix ${QT_OUTLIB} -fast -release -qt-mouse-tslib -qtlibinfix E -little-endian -no-webkit -no-qt3support -no-cups -no-largefile -optimized-qmake -no-openssl -nomake tools -qt-sql-sqlite -no-3dnow -system-zlib -qt-libtiff -qt-libpng -qt-libmng -qt-libjpeg -no-opengl -gtkstyle -no-openvg -no-xshape -no-xsync -no-xrandr -qt-freetype -qt-zlib -qt-gfx-transformed -nomake examples -opensource -confirm-license  -I${MULTITOUCH_OUT_DIR}/include -L${MULTITOUCH_OUT_DIR}/lib 2>&1 | tee -a ~/$0.log 

	make -j8 && make -j8 install  2>&1 | tee -a ~/$0.log
	echo "$0:$LINENO:Qt has been installed in .../qt-source/output" | tee -a ~/$0.log
	sudo cp -r $QT_OUTLIB/lib/* $ROOTFS_ROOT/usr/lib 
	echo "$0:$LINENO:Qt libs have been copied to rootfs /usr/lib" | tee -a ~/$0.log

}

#******************TOOLCHAIN**************************#
TOOLCHAIN_ROOT=${BUILD_DIR}/toolchain
TOOLCHAIN_VERSION=gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux

prepare_toolchain () {
	echo "$0:$LINENO:preparing tool chain" | tee -a ~/$0.log
	cd $TOOLCHAIN_ROOT
	
	#sudo apt-get -y install libc6-i386 lib32z1 lib32stdc++6
	#install Linaro compiler
	#zenity --info --text="Message:install linaro compiler" | tee -a ~/$0.log

	if [ -d "${TOOLCHAIN_VERSION}" ]; then
	echo "$0:$LINENO:Toolchain Directory Present, Must be installed!  ......." | tee -a ~/$0.log	
	else
		echo "$0:$LINENO:Toolchain Directory not Installed  ......." ${TOOLCHAIN_VERSION} | tee -a ~/$0.log	
		if [ ! -f "~/blobs/${TOOLCHAIN_VERSION}.tar.xz" ]; then
			echo "$0:$LINENO:~/blobs/${TOOLCHAIN_VERSION}.tar.xz Directory not Present... downloading ......." | tee -a ~/$0.log	
			wget http://releases.linaro.org/14.09/components/toolchain/binaries/${TOOLCHAIN_VERSION}.tar.xz  2>&1 | tee -a ~/$0.log
		fi
		echo "$0:$LINENO:Untar ${TOOLCHAIN_VERSION}......." | tee -a ~/$0.log	
		tar -xvf ~/blobs/${TOOLCHAIN_VERSION}.tar.xz 2>&1 | tee -a ~/$0.log
	fi	
	
	cd ${TOOLCHAIN_VERSION}/bin
	if grep -q ${TOOLCHAIN_VERSION} "${HOME}/.bashrc"; then
	echo "$0:$LINENO:PATH has already been updated   ......." | tee -a ~/$0.log	
   	continue
	else
	echo "export PATH=$PATH:$PWD" >> ~/.bashrc	
	
	zenity --info --text="Cross Compiler has been setup. Need to restart bash to take effect." | tee -a ~/$0.log 
	fi	
	echo "Cross Compiler setup done."        | tee -a ~/$0.log
	
}

#******************SINGLE & MULTITOUCH**************************#

TSLIB_PATH=~/SLPvf50/tslib
LIBRARY_PATH=${BUILD_DIR}/libraries/
REFERNCE_TSLIB=tslib-1.0_mt
TS_LIB=tslib-ts5x06
LIBLO=liblo-0.28
MTDEV=mtdev-1.1.5
LIB_QTUIO=${LIBRARY_PATH}/multitouch/qTUIO-master/qTUIO/lib_tou/

MULTITOUCH_OUT_DIR=${TSLIB_PATH}/output

compile_multitouch_libraries() {	
	exit #no don't do it
	echo "Building Tslib: this Tslib supports Hantronix 7 inch LCD and Projected Capacitive Display touchscreen only !!!!! .... " | tee -a ~/$0.log
	cd ${TSLIB_PATH}	
	echo "Fetching the  ${TS_LIB} Liraries.........." | tee -a ~/$0.log
	if [ ! -d "$TS_LIB" ]; then
		git clone  https://github.com/wojtekpil/$TS_LIB
	fi	
	cd $TS_LIB/tslib 
	patch -p1 -N --dry-run --silent < ${PATCH_DIR}/tslib.patch  2>/dev/null
	if [ $? -eq 0 ];
	then
	patch -p1 < $PATCH_DIR/tslib.patch
	else 
	echo " Patch not required   !!!!! .... " | tee -a ~/$0.log
	fi
	 echo $PWD 
		
	chmod 777 autogen*
	./autogen-clean.sh 
	./autogen.sh 
	./configure --host=${HOST} --prefix=${MULTITOUCH_OUT_DIR} --enable-shared=yes --enable-static=yes   	
	make && make install  
	#******************LIBLO**************************#
	cd ${TSLIB_PATH}	
	echo "building $LIBLO  Libraries" | tee -a ~/$0.log
	
	if [ ! -d "$LIBLO" ]; then
		echo "${LIBIO} not Present" | tee -a ~/$0.log
		if [ ! -f "${LIBLO}.tar.gz" ]; then
			echo "${LIBIO}.tar.gz not Present " | tee -a ~/$0.log
			wget nchc.dl.sourceforge.net/project/liblo/liblo/0.28/$LIBLO.tar.gz  2>&1 | tee -a ~/$0.log
		fi
		tar -xvf  ${LIBLO}.tar.gz  2>&1 | tee -a ~/$0.log
	fi

	cd ${LIBLO}
	./configure --host=${HOST} --prefix=${MULTITOUCH_OUT_DIR}  --enable-shared 
	make && make install  2>&1 | tee -a ~/$0.log
	
	cd ..
	#******************MTDEV**************************#
	cd ${TSLIB_PATH}
	
	if [ ! -d "${MTDEV}" ]; then
		echo "${MTDEV} not Present" | tee -a ~/$0.log
		if [ ! -f "mtdev-1.1.5.tar.gz" ]; then
			echo "mtdev-1.1.5.tar.gz not Present downloading....." | tee -a ~/$0.log
			wget http://bitmath.org/code/mtdev/mtdev-1.1.5.tar.gz  2>&1 | tee -a ~/$0.log
		fi
		tar -xvf  ${MTDEV}.tar.gz 2>&1 | tee -a ~/$0.log
	fi


	cd ${MTDEV}
	./configure --host=${HOST} --prefix=${MULTITOUCH_OUT_DIR}  --enable-shared  2>&1 | tee -a ~/$0.log
	make && make install 2>&1 | tee -a ~/$0.log
	#zenity --info --text="${MTDEV} has been installed in ${MULTITOUCH_OUT_DIR} . copying this libs to  rootfs /us/lib path ... "

	#https://github.com/olivopaolo/mtdev2tuio
	#******************Install Files**************************#	
	
	cp -r $MULTITOUCH_OUT_DIR/bin/* $ROOTFS_ROOT/usr/bin 
	cp -r $MULTITOUCH_OUT_DIR/lib/* $ROOTFS_ROOT/usr/lib 
	cp -r $MULTITOUCH_OUT_DIR/etc/* $ROOTFS_ROOT/etc 
	
}

#Linux Kernel  & device Drivers #
#******************LINUX-KERNEL**************************#
MACHINE=colibr_vf
LINUX_BSP=${BUILD_DIR}/linux-bsp
UBOOT_VER=2015.04-toradex
LINUX_VER=toradex_vf_4.1
LINUX_SRC=linux-toradex
U_BOOT_SRC=u-boot-toradex
ROOTFS_BOOT=${ROOTFS_ROOT}/boot
KERNEL_IMAGE=zImage
ARM_ARCH_PATH=arch/arm/boot
DTB_FILE=vf500-colibri-eval-v3.dtb
#U_BOOT_PATCHES=u-boot_patches

compile_linux_sources() { 
	#### this now point to Setra's repo	
	#******************U-BOOT **************************#
	echo "$0:$LINENO:compiling linux source files" | tee -a ~/$0.log
	cd ${LINUX_BSP}	
	cd ${U_BOOT_SRC}

	make colibri_vf_defconfig  2>&1 | tee -a ~/$0.log	
	echo "$0:$LINENO:compiling u-boot-toradex" | tee -a ~/$0.log
	make -j8 2>&1 | tee -a ~/$0.log 
	
	sudo rm -rf $UBIFS_DIR/colibri-vf_bin/u-boot.imx    
	sudo rm -rf $UBIFS_DIR/colibri-vf_bin/u-boot-nand.imx 
	sudo cp u-boot.imx $UBIFS_DIR/colibri-vf_bin
	sudo cp u-boot-nand.imx $UBIFS_DIR/colibri-vf_bin
	echo "$0:$LINENO:done compiling u-boot"  | tee -a ~/$0.log
	#******************LINUX-KERNEL**************************#
	cd ${LINUX_BSP}	
	cd $LINUX_SRC
	cp -r $PATCH_DIR/logo_custom_clut224.ppm drivers/video/logo
	
	echo "$0:$LINENO:compiling linux-toradex" | tee -a ~/$0.log
	make -j8 $KERNEL_IMAGE 2>&1 | tee -a ~/$0.log
	make  -j8 $DTB_FILE  2>&1 | tee -a ~/$0.log
	make  -j8 modules  2>&1 | tee -a ~/$0.log

	echo "$0:$LINENO:done compiling linux-toradex" | tee -a ~/$0.log

	#use sudo in case build failed last time and permissons are wonky
	sudo rm -rf $ROOTFS_BOOT/$KERNEL_IMAGE
	sudo rm -rf $ROOTFS_BOOT/$DTB_FILE

	echo "$0:$LINENO:installing  Kernel & DTB .............removing old boot and copying new one over"

	sudo rm -rf ${ROOTFS_BOOT}/*

	sudo cp $ARM_ARCH_PATH/$KERNEL_IMAGE ${ROOTFS_BOOT} 2>&1 | tee -a ~/$0.log
	sudo cp $ARM_ARCH_PATH/dts/$DTB_FILE ${ROOTFS_BOOT} 2>&1 | tee -a ~/$0.log

	sudo rm -rf ${ROOTFS_ROOT}/lib/modules/*
	sudo chown -R $USER ${ROOTFS_ROOT}

	echo "$0:$LINENO:installing  modules ............."
	make -j8 INSTALL_MOD_PATH=${ROOTFS_ROOT}  modules_install 2>&1 | tee -a ~/$0.log
	sudo chown -R root ${ROOTFS_ROOT}
	#because some moron in SoftDel needs to have two copies of this or it won't work
	echo "$0:$LINENO:copy adc driver ko file to home/root"
	sudo cp -r ./drivers/iio/adc/ad7793.ko ${ROOTFS_ROOT}/home/root
	echo "$0:$LINENO:Complete build of Linux Sources."
}

prepare_splash_image(){
	echo "$0:$LINENO:creating splash image file" | tee -a ~/$0.log
	cd ~/SLPvf50/patches/splash
	splash_file=$(zenity --file-selection)
	convert $splash_file -resize 800x480\!    test.jpg
	convert test.jpg test.ppm
	ppmquant 224 test.ppm > test1.ppm
	pnmnoraw test1.ppm  > logo_custom_clut224.ppm
	mv logo_custom_clut224.ppm ~/SLPvf50/linux-bsp/linux-toradex/drivers/video/logo
#	rm test.jpg *ppm
}



copy_libs_bin()
{
    echo "$0:$LINENO:Copying Libs, bin into patch area\n" | tee -a ~/$0.log
    #just in case someone cloned patches recently, check for empty dir.s missing
    cd ~/SLPvf50
    cd patches
    if [ ! -d "application_libs" ]; then
        mkdir application_libs
    fi

    if [ ! -d "setra_build/libs" ]; then
        mkdir setra_build/libs
    fi

    if [ ! -d "MSTP" ]; then
        mkdir MSTP
    fi

    if [ ! -d "setra_build/bin" ]; then
        mkdir setra_build/bin
    fi
    
    cd ~/QtProjects

    #copy bacnet stacks over to the image
    sudo cp slpdrivers/BACNet/StackLib/*so ~/SLPvf50/ubifs/rootfs/usr/lib/
    #insanely make another copy here to overwirin' them
    sudo cp slpdrivers/BACNet/StackLib/*so ~/SLPvf50/patches/application_libs/


    cd $LIB_DIR
    cd ..
    rm -rf libs/*  #safety first!
    #copy files over to patches area before building image
    cd ~/QtProjects/build
    echo "$0:$LINENO:Copying into $LIB_DIR"                   | tee -a ~/$0.log
    echo "$0:$LINENO:  and $BIN_DIR"		              | tee -a ~/$0.log
    cp -pr BackLight/libBackLight.so* $LIB_DIR
    cp -pr BACNet/libBACNet.so* $LIB_DIR
    cp -pr Ethernet/libEthernet.so* $LIB_DIR
    cp -pr HWComm/libHWComm.so* $LIB_DIR
    cp -pr IOComm/libIOComm.so* $LIB_DIR
    cp -pr Log/libLog.so* $LIB_DIR
    cp -pr qpcap/libqpcap.so* $LIB_DIR
    cp -pr UsbUpgrade/libUsbUpgrade.so* $LIB_DIR
    cp -pr NG-RPM $BIN_DIR		
    cp -pr $HOME/QtProjects/slpdrivers/BACNet/StackLib/mstp/mstp.ko $PATCH_DIR/MSTP/mstp.ko
    echo "$0:$LINENO:Done copying the libs and bins"
}

update_version() {
    cd ~/QtProjects
    cd ngrpm-app

    echo ""
    echo "********* Incrementing build number ****************" 

    GIT_SHA=$(git log -1 --pretty=format:%h)
    GIT_SHA_STR="GIT_SHA = $GIT_SHA"
    sed -i "4s/.*/$GIT_SHA_STR/" version.pri

    echo ""
    perl -i.orig -pe '/VERSION_BUILD/ && s/(\d+)($)/$1+1 . $2/e' version.pri
    git add version.pri
    git commit -m "AppVersion updated to ${VERSION_MAJOR}.${VERSION_MINOR}.$(awk -F=. '/VERSION_BUILD/ { print int($2); }' version.pri); author:build_and_release"
}

#START FUNCTION #
cd

echo "start me up"

export ARCH=arm
export CROSS_COMPILE=${HOST}-

MENU="
***************************
Build Script Version : 5.00
>> 
***************************

1 COMPILE_QT_SOURCE
2 COMPILE_LINUX_SOURCE
3 COMPILE THE BACNET STACK 
4 BUILD Linux, BACnet, Copy Libs Bins
5 COPY_LIBS_BIN
6 PREPARE_SPLASH_SCREEN
7 FLASH_IMAGE TO SDCARD
8 Prep tftp area
9 Build for Release
13 EXIT
"
 
while true	; do
  clear
  echo "$MENU"
  echo -n "Please make your choice: "
  read INPUT # Read user input and assign it to variable INPUT
 
echo $INPUT 
  case $INPUT in
 	
    1) 	 	
	compile_qt_source
	echo press ENTER to continue
	read
	;;
    2)	
	compile_linux_sources
	echo press ENTER to continue
	read
	;;
    3)	
	compile_bacnet
	echo press ENTER to continue
	read
	;;
    4)	
	compile_linux_sources	
	compile_bacnet
	copy_libs_bin
	#flash_image
	echo press ENTER to continue
	read
	;;
    
    5)
        copy_libs_bin
        echo press ENTER to continue
        read
        ;;	

    6)	
	prepare_splash_image
	echo press ENTER to continue
	read
	;;
    7)	
	flash_image
	echo press ENTER to continue
	read
	;; 		
    8)
	prep_tftp
	cd ~/scripts
ls -al
	source ./commit-hash.sh
        echo press ENTER to continue
        read
	;;
    9)
	prepare_splash_image
	compile_qt_source
	compile_linux_sources	
	compile_bacnet
	copy_libs_bin
	prep_tftp
	#updates the version in ngrpm-app
	#update_version
	cd ~/scripts
ls -al
	source ./commit-hash.sh
	echo "Hash files created"
        echo press ENTER to continue
        read
	;;
    13|q|Q) # If user presses 3, q or Q we terminate
        exit 0
        ;;
    *) # All other user input results in an usage message
        clear
        ;;
  esac
done

