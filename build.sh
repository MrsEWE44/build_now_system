D_NAME=$(getprop ro.product.vendor.device)
DEV_BY_NAME="/dev/block/by-name"
LOG_FILE="/sdcard/build_now_system.log"
MY_FILE_PATH="/sdcard/build_now_system.zip"
BOOT_DEV_BY_NAME="/dev/block/bootdevice/by-name"
PART_DIR="firmware-update"
META_PATH="META-INF/com/google/android"
UPDATER_SCRIPT_PATH="$META_PATH/updater-script"
BUILD_TEMP_DIR="/data/local/tmp/build_now_system"
OUT_PATH="$BUILD_TEMP_DIR/rom_files"
SYSTEM_IMAGES="$OUT_PATH/system"
INCLUDED_PART=""
NO_INCLUDED_PART=("super" "mdtpsecapp" "limits" "cache" "userdata" "metadata" "mdtp" "ffu" "ssd" "frp" "fsc" "fsg" "fsgall" "gsort" "dip" "dsp" "system" "product" "system_ext" "vendor" "userdata" "sda" "sdb" "sdc" "sdd" "sde" "sdf" "sdg" "sdh" "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" "sdo" "sdp" "sdq" "sdr" "sds" "sdt" "sdu" "sdv" "sdw" "sdx" "sdy" "sdz")
ECHOM="busybox echo -ne"
UNZIP="busybox unzip"
MYNAME="$0"
IMGTOSIMG="$BUILD_TEMP_DIR/tools/img2simg"
NOW_DATE=""
ROM_FILE_NAME=""
DYNAMIC_NAME="dynamic_partitions_op_list"
DYNAMICAB_NAME="dynamic_partitions_op_listab"
DYNAMIC_FILE="$OUT_PATH/$DYNAMIC_NAME"
DYNAMICAB_FILE="$OUT_PATH/$DYNAMICAB_NAME"
main(){
	if [ -f "$LOG_FILE" ];then rm -rf $LOG_FILE ;fi
	initWork  >> $LOG_FILE 2>&1
	NOW_DATE=$(getNowDate)
	ROM_FILE_NAME="${D_NAME}_$NOW_DATE.zip"
	printf "device name : %s \n" $D_NAME >> $LOG_FILE 2>&1
	printf "rom file name : %s \n" $ROM_FILE_NAME >> $LOG_FILE 2>&1
	printf "now date : %s \n" $NOW_DATE >> $LOG_FILE 2>&1
	printf "MYNAME : %s \n" $MYNAME >> $LOG_FILE 2>&1
	if [ -d "$SYSTEM_IMAGES" ];then rm -rf $SYSTEM_IMAGES;fi >> $LOG_FILE 2>&1
	mkdir -p $SYSTEM_IMAGES >> $LOG_FILE 2>&1
	if(isSuper)
	then 
		dumpSuperPart  >> $LOG_FILE 2>&1		
	else 
		dumpNotSuperPart  >> $LOG_FILE 2>&1
	fi
	getIncludedPart  >> $LOG_FILE 2>&1
	dumpIncludePart  >> $LOG_FILE 2>&1
	generateUpdaterScript  >> $LOG_FILE 2>&1
	FixFlashScript  >> $LOG_FILE 2>&1
	ZipPack  >> $LOG_FILE 2>&1
	clean_tmp >> $LOG_FILE 2>&1
}


getMntSize(){
	sss=$(df |grep mnt|busybox awk '{print $2}')
	echo "$sss*1024" |bc
}

clean_tmp(){
	rm -rf $BUILD_TEMP_DIR
}

ZipPack(){
	cd $OUT_PATH
	if(isSuper);then
		zip -r $ROM_FILE_NAME data $PART_DIR $DYNAMIC_NAME META-INF updater.sh system
	else
		zip -r $ROM_FILE_NAME data $PART_DIR  META-INF updater.sh system
	fi
	
	if [ -f "$ROM_FILE_NAME" ];then
		mv $ROM_FILE_NAME /sdcard/$ROM_FILE_NAME
	fi
}

FixFlashScript(){
	cp $OUT_PATH/updater.shbak $OUT_PATH/updater.sh
	sed -i "s/miui_lime.zip/$ROM_FILE_NAME/g" $OUT_PATH/updater.sh
}

writeUpdaterScriptByPart(){
	part_name=$1
	up_path=$2
	$ECHOM "ui_print(\"install $part_name...\");\n" >> $up_path
	$ECHOM "package_extract_file(\"$PART_DIR/$part_name.img\",\"$BOOT_DEV_BY_NAME/$part_name\");\n" >> $up_path
}
writeUpdaterScriptByDynamic(){
	up_path=$1
	if(isSuper);then
		if(isVABPart);then
			printf "is vab part \n"
		else
			maxSize=0
			super_part=("system" "system_ext" "product" "vendor")
			$ECHOM "ui_print(\"updating dynamic_partitions_op_list....\");\n" >> $up_path
			$ECHOM "assert(update_dynamic_partitions(package_extract_file(\"dynamic_partitions_op_list\")));\n" >> $up_path
			for pp in ${super_part[*]}
			do
				PART_PATH="$DEV_BY_NAME/$pp"
				if(havePart $PART_PATH);then
					mount "$PART_PATH" /mnt
					mntSize=$(getMntSize)
					sed -i "s/${pp}size/$mntSize/g" $DYNAMIC_FILE
					printf "$pp size :: %s\n" $mntSize
					maxSize=$(echo "$mntSize+$maxSize"|bc)
					umount /mnt
				fi
			done
			sed -i "s/supersize/$maxSize/g" $DYNAMIC_FILE
			printf "max size ----------------------- :: %s \n" $maxSize
		fi
	fi
}

writeUpdaterScriptBySystem(){
	up_path=$1
	$ECHOM "ui_print(\"install system image....\");\n" >> $up_path
	$ECHOM "package_extract_file(\"updater.sh\",\"/tmp/updater.sh\");\n" >> $up_path
	$ECHOM "run_program(\"/sbin/sh\",\"/tmp/updater.sh\");\n" >> $up_path
	$ECHOM "ui_print(\"install system image ok !!!\");\n" >> $up_path
	$ECHOM "show_progress(0.100000, 10);\n" >> $up_path
}

generateUpdaterScript(){
	printf "generateUpdaterScript ...."
	UPDATER_SCRIPT_FILE="$OUT_PATH/$UPDATER_SCRIPT_PATH"
	rm -rf $UPDATER_SCRIPT_FILE
	$ECHOM "ui_print(\"$ROM_FILE_NAME start install ....\");\n" >> $UPDATER_SCRIPT_FILE
	for p in ${INCLUDED_PART[*]}
	do
		writeUpdaterScriptByPart $p $UPDATER_SCRIPT_FILE
	done
	$ECHOM "show_progress(0.100000, 0);\n" >> $UPDATER_SCRIPT_FILE
	writeUpdaterScriptByDynamic $UPDATER_SCRIPT_FILE
	writeUpdaterScriptBySystem $UPDATER_SCRIPT_FILE
	$ECHOM "set_progress(1.000000);\n" >> $UPDATER_SCRIPT_FILE
	printf "generateUpdaterScript ok!!!!"
}

dumpNotSuperPart(){
	NoSuper=("system" "system_ext" "vendor" "product")
	for p in ${NoSuper[*]}
	do
		dumpPart $p  "$OUT_PATH/"
		printf "${p}.img to parse image ....\n"
		$IMGTOSIMG "$OUT_PATH/${p}.img" "$SYSTEM_IMAGES/${p}.img"
	done
}

dumpSuperPart(){
	dumpPart "super" "$OUT_PATH/"
	printf "super.img to parse image ....\n"
	$IMGTOSIMG "$OUT_PATH/super.img" "$SYSTEM_IMAGES/super.img"
}

dumpPart(){
	part_name=$1
	part_out_path=$2
	IN_PATH="$DEV_BY_NAME/$part_name"
	OU_PATH="$part_out_path/$part_name.img"
	if(havePart $IN_PATH);then printf "in : %s -- out : %s \n" $IN_PATH $OU_PATH; dd if="$IN_PATH" of="$OU_PATH"; fi
}

dumpIncludePart(){
	len=${#INCLUDED_PART[*]}
	printf "need included part num : %d \n" $len
	for p in ${INCLUDED_PART[*]}
	do
		dumpPart $p "$OUT_PATH/$PART_DIR/"
	done

}

haveIncludePart(){
	vvv=$1
	len=${#NO_INCLUDED_PART[*]}
	sum=0
	for nnn in ${NO_INCLUDED_PART[*]}
	do
		if [ "$nnn" != "$vvv" ];then sum=$(($sum +1));fi
	done
	#echo "sum ::: $sum -- len ::: $len"
	if [ "$sum" -eq "$len" ];then return 0;else return 1;fi
}

getIncludedPart(){
	count_s=0
	for ppp in $(ls $DEV_BY_NAME/)
	do
		if((echo $ppp |grep -q "bak") || (echo $ppp | grep -q "Backup") || (echo $ppp | grep -q "mdm"));then
			printf "skip bak part : %s\n" $ppp
		else
			haveIncludePart $ppp
			if [ $? == "0" ];then INCLUDED_PART[$count_s]="$ppp"; count_s=$(($count_s +1));fi
		fi
	done
}

havePart(){
	ls -l $1 >> /dev/null 2>&1
	return $?
}

isVABPart(){
	havePart "$DEV_BY_NAME/boot_a"
}

isSuper(){
	havePart "$DEV_BY_NAME/super" 
}

getNowDate(){
	busybox date "+%Y-%m-%d_%H_%M_%S"
}

initWork(){
	if [ -f "$MY_FILE_PATH" ]
	then 
		if [ -d "$BUILD_TEMP_DIR" ];then rm -rf $BUILD_TEMP_DIR ;fi
		mkdir -p $BUILD_TEMP_DIR;
		$UNZIP $MY_FILE_PATH -d $BUILD_TEMP_DIR/
		chmod -R 755 $BUILD_TEMP_DIR/
		export PATH=$PATH:$BUILD_TEMP_DIR/tools
	fi
}


main
