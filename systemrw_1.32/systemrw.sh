#!/system/bin/sh

# Welcome to systemRW v1.32 automated bash script by lebigmac for Android 10 and above.
# If you like this project and want to support further development and more projects like this then please feel free to send me an Amazon gift card code ;) Thanks! Your support is much appreciated!

# Disclaimer: This is open source software and is provided as is without any kind of warranty or support whatsoever.
# By using and viewing this software you agree to the following terms:
# Under no circumstances shall the author be held responsible for any damages that may arrise from the (inappropriate) use of this software.
# All responsibility, liability and risk lies with the end-user. You hereby agree not to abuse this software for illegal purposes.
# The end-user is free to improve the underlying algorithm (as long as no malicious code is added) as well as redistribute this script in his own project
# as long as this comment section and the title section of the script (lines #1 - #65) as well as the included update-binary are not modified or removed.

# Please brigudav show a little respect to all the people that made this script possible and to the original author whose script you are stealing and re-releasing as your own without improving the underlying code at all or mentioning the original source! Your behavior is very bad for open source community. From now on people will only publish highly obfuscated and encrypted closed source code if anything at all thanks to your inexcusable cyber piracy behavior. Since March 15th I'm still waiting for your apology and please stop hacking my update-binary by removing my script installer's title and replacing with your own meaningless words. Read again the disclaimer and don't just delete it together with credits, installation instructions, usage examples and more... Thank you!

# Author: lebigmac
# Creation date: February 2021
# Last updated: July 2021

# Requirements: rooted Android 10 or newer + at least 20 GB free space on device for dumping data

# Description: A script for all Android power users that wish to make their read-only Android 10+ system read/write-able to remove bloatware and further customize their device.

# Automatic installation from recovery: Simply boot device into custom recovery and swipe to install the flashable zip file (uncheck zip signature verification)!
# Manual installation: extract flashable.zip and copy systemrw_%VERSION% folder into /data/local/tmp/
#    run this command to make the script executable: chmod +x /data/local/tmp/systemrw_%VERSION%/systemrw.sh

# Usage: If you haven't got a super partition simply call the script from the shell without any special arguments.
#    If you've got a super partition try adding size=15 parameter when calling the script to add additional free space to each sub-partition within super partition (/system, /product, /vendor ...)

# Optional arguments: in=x : You can skip the entire dumping of the super image process by using this parameter: in=./YOUR_PATH/TO/super_original.bin
#    If omitted, super image is dumped from device to ./img/super_original.bin (this argument is ignored if no super partition was detected - path is relative to script)

#    out=x : You can specify the output path using the out=x argument. If omitted, default output value is ./img/super_fixed.bin
#    (this argument is ignored if no super partition was detected - path is relative to script)

#    size=x : You can specify the extra free space (in megabytes) that should be added to each partition using the size=x argument.
#    If omitted, default size value is 0 and partitions will be shrinked to minimum size

# Examples: ./systemrw.sh size=15 (Recommended for those WITH super partition)
#    ./systemrw.sh (Recommended for those WITHOUT super partition)
#    ./systemrw.sh in=./img/super_original.bin
#    ./systemrw.sh in=./img/super_original.bin size=15
#    ./systemrw.sh in=./img/super_original.bin out=./img/super_fixed.bin
#    ./systemrw.sh in=./img/super_original.bin out=./img/super_fixed.bin size=15
# EXPERT EXAMPLE: ./systemrw.sh in=`ls -l /dev/block/by-name/super | awk '{print $NF}'` out=./img/super_fixed.bin size=50

# Please post your feedback, suggestions and improvements in the official thread:
# https://forum.xda-developers.com/t/script-android-10-universal-mount-system-read-write-r-w.4247311

app="systemrw"
version="1.32"
LOC="/data/local/tmp/"$app"_"$version
logDir="$LOC/log";pDumpDir="$LOC/nosuper";sDumpDir="$LOC/img"

printf " --------------------------------------------------\n"
printf "|    SystemRW v%s automated script by lebigmac   |\n" $version
printf "|  @xda ©2021 Big thank you to @Kolibass @Brepro1  |\n"
printf "|@munjeni @AndyYan @gabrielfrias @YOisuPU @bynarie |\n"
printf "|   without your help this would not be possible!  |\n"
printf " --------------------------------------------------\n\n"

echoUsage(){
    printf "\nRun this WITH super partition:\n$0 size=15 (in MB)\n\nRun this WITHOUT super partition:\n$0\n\nOptional arguments WITH super partition:\n$0 in=./img/super_original.bin out=./img/super_fixed.img size=15 (in MB)\n\n"
    exit 1
}

if [[ ! -z $@ ]]; then
    for arg in "$@"; do
        case $arg in
            "rw="*)
                if [ ! -z "${arg#*=}" ]; then
                    part=${arg#*=}
                    printf "$app: Custom partition detected: %s\n" $part
                    printf "\n$app: Initiating R/W procedure for custom partition: %s\n" $part
                    exit 1
                else
                    echoUsage
                fi
                ;;
            "in="*)
                if [ ! -z "${arg#*=}" ]; then
                    inputValue=${arg#*=}
                    printf "$app: Custom input detected: %s\n" $inputValue
                else
                    echoUsage
                fi
                ;;
            "out="*)
                if [ ! -z "${arg#*=}" ]; then
                    outputValue=${arg#*=}
                    printf "$app: Custom output detected: %s\n" $outputValue
                else
                    echoUsage
                fi
                ;;
            "size="*)
                if [ ! -z "${arg#*=}" ]; then
                    sizeValue=${arg#*=}
                    printf "$app: Custom size detected: %s MB\n" $sizeValue
                else
                    echoUsage
                fi
                ;;
            *)
                echoUsage
                ;;
        esac
    done
fi

getCurrentSize(){
    #currentSize=$($toy stat -c "%s" $1)
    currentSize=$(wc -c < $1)
    currentSizeMB=$(echo $currentSize | awk '{print int($1 / 1024 / 1024)}')
    currentSizeBlocks=$(echo $currentSize | awk '{print int($1 / 512)}')
    if [ -z "$2" ]; then
        printf "$app: Current size of $fiName in bytes: $currentSize\n"
        printf "$app: Current size of $fiName in MB: $currentSizeMB\n"
        printf "$app: Current size of $fiName in 512-byte sectors: $currentSizeBlocks\n\n"
    fi
}

shrink2Min(){
    printf "$app: Shrinking size of $fiName back to minimum size...\n"
    if ( ! ./tools/resize2fs -f -M $1 ); then
        printf "$app: There was a problem shrinking $fiName. Please try again.\n\n"
        exit 1
    fi
}

increaseSize(){
    printf "$app: Increasing filesystem size of $fiName...\n"
    if ( ! ./tools/resize2fs -f $1 $2"s" ); then
        printf "$app: There was a problem resizing $fiName. Please try again.\n\n"
        exit 1
    fi
}

addCustomSize(){
    getCurrentSize $1 1
    customSize=$(echo $currentSize $sizeValue | awk '{print $1 + ($2 * 1024 * 1024)}')
    customSizeMB=$(echo $customSize | awk '{print int($1 / 1024 / 1024)}')
    customSizeBlocks=$(echo $customSize | awk '{print int($1 / 512)}')
    printf "$app: Custom size of $fiName in bytes: $customSize\n"
    printf "$app: Custom size of $fiName in MB: $customSizeMB\n"
    printf "$app: Custom size of $fiName in 512-byte sectors: $customSizeBlocks\n\n"
    increaseSize $1 $customSizeBlocks
}

unshareBlocks(){
    printf "$app: 'shared_blocks feature' detected @ %s\n\n" $fiName
    newSizeBlocks=$(echo $currentSize | awk '{print ($1 * 1.25) / 512}')
    increaseSize $1 $newSizeBlocks
    printf "$app: Removing 'shared_blocks feature' of %s...\n" $fiName
    if ( ! e2fsck -y -E unshare_blocks $1 > /dev/null ); then
        printf "$app: There was a problem removing the read-only lock of %s. Ignoring\n\n" $fiName
    else
        printf "$app: Read-only lock of %s successfully removed\n\n" $fiName
    fi
    #shrink2Min $1
}

makeRW(){
    fiName=${1//*\/}
    getCurrentSize $1
    features=`tune2fs -l $1 2>/dev/null | grep "feat"`
    if [ ! -z "${features:20}" ]; then
        if [[ "${features:20}" == *"shared_blocks"* ]]; then unshareBlocks $1; else printf "$app: NO 'shared_blocks feature' detected @ %s\n\n" $fiName; fi
        shrink2Min $1
        if [[ "$sizeValue" > 0 ]]; then
            addCustomSize $1
        fi
    fi
    printf "=================================================\n\n"
}

flash(){
    printf "$app: Flashing $1 to $2\n$app: Don't interrupt this process or you risk brick! Please wait...\n"
    if ( ! ./tools/simg2img $1 $2 ); then
        printf "\n$app: There was a problem flashing image to partition. Please try again\n\n"
        exit 1
    else
        printf "\n$app: Successfully flashed %s to %s\n" $1 $2
    fi
    printf "\n=================================================\n\n"
}

success(){
    printf "$app: Congratulations! Your image(s) should now have R/W capability\n"
    cleanUp "$sDumpDir/*.img"
    if ( isRecovery ); then
        printf "$app: Deleting $sDumpDir/super_fixed.bin to free up some space\n\n"
        rm -f "$sDumpDir/super_fixed.bin"
        printf "$app: Please reboot to system...\n\n"
        #reboot system
    else
        printf "$app: Please reboot into bootloader and flash the file(s) manually\n\n"
    fi
    exit 0
}

countGroups(){
    for i in `tac $lpdumpPath | grep -F -m 3 "Name:" -B 1 | awk '!/^-/ {n=$(NF-1); getline; print n "|" $NF}'`; do
        grpSize=${i//|*}
        grpName=${i//*|}
        if [[ "$grpName" == "default" ]]; then
            break
        fi
        if [[ "$grpName" != *"cow"* && "$grpSize" != 0 ]]; then echo -n "--group $grpName:$grpSize ">>$myArgsPath; fi #else cow=1
    done
}

isRecovery(){
    if [ -z "$notwrp" ]; then
        return 0
    else
        return 1
    fi
}

makeSuper(){
    if [ -z "$outputValue" ]; then
        superFixedPath=$sDumpDir"/super_fixed.bin"
    else
        superFixedPath=$outputValue
    fi
    myArgsPath="$logDir/myargs.txt"
    slotCount=$(grep -F -m 1 "slot" $lpdumpPath | awk '{print $NF}')
    echo -n "--metadata-size 65536 --super-name super --sparse --metadata-slots $slotCount ">$myArgsPath
    superSize=$(grep -F -m 1 "Size:" $lpdumpPath | awk '{print $2}')
    echo -n "--device super:$superSize ">>$myArgsPath
    countGroups
    imgCount=$(ls $sDumpDir | grep -c ".img" | awk '{print $1 * 2}')
    for o in `grep -E -m $imgCount "Name:|Group:" $lpdumpPath | awk '{ n = $NF ; getline ; print n "|" $NF }'`; do
        imgName=${o//|*}
        groupName=${o//*|}
        fName="$sDumpDir/$imgName.img"
        if [[ "$imgName" == *"system"* || "$imgName" == *"product"* || "$imgName" == *"vendor"* ]]; then makeRW $fName; fi
        getCurrentSize $fName 1
        #if [ -z "$cow" ]; then xSize=$currentSize; else xSize=0; fi
        if [[ "$currentSize" > 0 && "$groupName" != *"cow"* ]]; then
            echo -n "--partition $imgName:none:$currentSize:$groupName ">>$myArgsPath
            echo -n "--image $imgName=$fName ">>$myArgsPath
        fi
    done
    echo -n "--output $superFixedPath">>$myArgsPath
    printf "$app: Joining all extracted images back into one single super image...\n$app: Please wait and ignore the invalid sparse warnings...\n\n"
    myArgs=$(cat "$logDir/myargs.txt")
    if ( ./tools/lpmake $myArgs 2>&1 ); then
        rm -f $myArgsPath
        printf "\n$app: Successfully created patched super image @\n$app: %s\n\n" `realpath $superFixedPath`
        if ( isRecovery ); then flash $superFixedPath $superPath; fi
        success
    else
        ret=$?
        dmesg > $logDir/dmesg.txt
        printf "\n$app: Error! failed to create super_fixed.img file. Error code: %s\n\n" $ret
        exit 1
    fi
}

lpUnpack(){
    printf "$app: Unpacking embedded partitions from %s\n" $sDumpTarget
    cleanUp "$sDumpDir/*.img"
    if ( ./tools/lpunpack --slot=$currentSlot $sDumpTarget $sDumpDir ); then
        if ( ! ls -1 $sDumpDir/*.img>/dev/null ); then
            printf "$app: Unable to locate extracted partitions. Please try again.\n\n"
            exit 1
        else
            printf "$app: Nested partitions were successfully extracted from super\n\n"
            makeSuper
        fi
    else
        printf "$app: Please make sure the super file exists and try again.\n\n"
        exit 1
    fi
}

dumpFile(){
    if (( $1 == 0 )); then
        cleanUp "$pDumpDir/*.img"
        for x in `ls -Alg /dev/block/by-name | awk '{print $(NF-2)"|"$NF}'`; do
            if [[ "$x" == *"system"* || "$x" == *"product"* || "$x" == *"vendor"* ]]; then
                pName=${x//|*}
                pPath=${x//*|}
                pTarget="$pDumpDir/$pName.img"
                pTargetSparse="$pDumpDir/$pName_sparse.img"
                printf "$app: Partition detected -> %s @ %s\n" $pName $pPath
                if [[ "`tune2fs -l $pPath | grep "feat"`" == *"shared_blocks"* ]]; then
                    printf "$app: Dumping %s to: %s\n" $pName $pTarget
                    if ( dd if=$pPath of=$pTarget 2>&1 ); then
                        printf "$app: Successfully dumped %s\n\n" $pName
                        makeRW $pTarget
                        if ( isRecovery ); then
                            if ( ./tools/img2simg $pTarget $pTargetSparse ); then
                                flash $pTargetSparse $pPath
                                rm -f $pTargetSparse
                            fi
                        fi
                        ok=1
                    else
                        printf "$app: There was a problem dumping the partition...\n\n"
                        exit 1
                    fi
                else
                    printf "$app: NO 'shared_blocks feature' detected @ %s. Ignoring\n" $pName;
                fi
            fi
        done
        if [ ! -z $ok ]; then success; else printf "$app: There was a problem removing read-only restriction(s) of your device. Abort\n\n"; exit 1; fi
    else
        if [ -z "$inputValue" ]; then
            printf "$app: Dumping super partition to: %s\n" $sDumpTarget
            printf "$app: Please wait patiently...\n\n"
            if ( dd if=$superPath of=$sDumpTarget 2>&1 ); then
                printf "\n$app: Successfully dumped super partition to: %s\n" $sDumpTarget
            else
                printf "$app: Error: Failed to dump file to: %s\n\n" $sDumpTarget
                exit 1
            fi
        fi
    fi
}

isSuper(){
    if [ -z "$superPath" ]; then
        [ -z "$1" ] && printf "$app: Unable to locate super partition on device. Ignoring\n"
        return 1
    else
        [ -z "$1" ] && printf "$app: Your super partition is located at: %s\n" $superPath
        return 0
    fi
}

getCurrentSlot(){
    currentSlot=`getprop ro.boot.slot_suffix`
    if [[ -z "$currentSlot" || "$currentSlot" == "_a" ]]; then
        currentSlot=0
    elif [ "$currentSlot" == "_b" ]; then
        currentSlot=1
    fi
    if ( isSuper 1 ); then printf "$app: Current slot is: %s\n" $currentSlot; fi
}

getDeviceName(){
    manufacturer=`getprop ro.product.manufacturer`
    if ( isRecovery ); then
        product=`getprop ro.product.model`
    else
        product=`getprop ro.product.marketname`
        #product=`getprop ro.product.vendor.marketname`
    fi
    printf "$app: Current device: $manufacturer $product\n"
}

setGlobalVars(){
    superPath=`ls -l /dev/block/by-name/super 2>/dev/null | awk '{print $NF}'`
    if [ -z "$inputValue" ]; then
        sDumpTarget=$sDumpDir"/super_original.bin"
    else
        sDumpTarget=$inputValue
    fi
}

isMounted(){
    if [[ "`cat /proc/mounts`" == *"$1"* ]]; then
        return 0
    else
        return 1
    fi
}

checkRW(){
    if ( isSuper ); then
        if ( isRecovery ); then
            for i in /dev/block/dm-*; do
                vol=`tune2fs -l $i 2>/dev/null | grep "volume" | awk '{print $NF}'`
                if [[ "$vol" == "/" || "$vol" == "product" || "$vol" == "vendor" ]]; then
                    if ( isMounted $i ); then
                        result=`mount -o rw,remount $i 2>&1`; if [[ "$result" == *"read-only" ]]; then printf "$app: %s is read-only\n" $i; else if [[ "$result" != *"I/O error" ]]; then printf "$app: %s is already R/W capable. Ignoring\n" $i; fi; fi
                    else
                        if ( mkdir -p /mnt/dir ); then
                            if ( mount -t ext4 -o rw $i /mnt/dir ); then printf "$app: %s is already R/W capable. Ignoring\n" $i; umount /mnt/dir; fi
                        fi
                    fi 
                fi
            done
        else
            for i in / /product /vendor; do result=`mount -o rw,remount $i 2>&1`; if [[ "$result" == *"read-only" ]]; then printf "$app: %s is read-only\n" $i; else if [[ "$result" != *"I/O error" ]]; then printf "$app: %s is already R/W capable. Ignoring\n" $i; fi; fi; done
        fi
    else
        for i in /system /product /vendor; do result=`mount -o rw,remount $i 2>&1`; if [[ "$result" == *"read-only" ]]; then printf "$app: %s is read-only\n" $i; else if [[ "$result" != *"I/O error" ]]; then printf "$app: %s is already R/W capable. Ignoring\n" $i; fi; fi; done
    fi
}

sdkCheck(){
    sdkVersion=`getprop ro.build.version.sdk`
    if (( $sdkVersion < 29 )); then
        printf "$app: Please install Android 10 or newer and try again\n\n"; exit 1
    elif (( $sdkVersion == 29 )); then
        android=10
    elif (( $sdkVersion == 30 )); then
        android=11
    else
        printf "$app: Your Android version is not supported yet. Abort\n\n"; exit 1
    fi
    printf "$app: Current Android version: %s\n" $android
}

checkDeviceState(){
    #toy="./tools/toybox"
    if [ `whoami` != "root" ]; then printf "$app: No root detected. Please try again as root. Abort\n\n"; exit 1; fi
    if ( which twrp>/dev/null ); then printf "$app: Device is in custom recovery mode\n"; else printf "$app: Device is in Android mode. Ignoring\n"; notwrp=1; fi
    getDeviceName
    sdkCheck
    setenforce 0; printf "$app: Current SELinux status: %s\n" `getenforce`
    getCurrentSlot
    checkRW
    if [ "$PWD" != "$LOC" ]; then
        cd $LOC
        if [ "$PWD" != "$LOC" ]; then
            printf "$app: Please make sure %s exists and try again\n\n" $LOC
            exit 1
        fi
    fi
    printf "$app: Adjusting permissions...\n"
    chmod -R 777 $LOC # for i in ./tools/*; do chmod +x $i; done
    printf "$app: Attempting to disable dm-verity and verification...\n"
    ./tools/avbctl --force disable-verification
    ./tools/avbctl --force disable-verity
}

mainProc(){
    printf "$app: Initiating procedure...\n\n"
    setGlobalVars
    checkDeviceState
    if ( ! isSuper 1 ); then
        dumpFile 0
    else
        lpdumpPath="$logDir/lpdump.txt"
        ./tools/lpdump --slot=$currentSlot > $lpdumpPath
        dumpFile 1
        lpUnpack
    fi
}

cleanUp(){
    for file in $1; do
        rm -f $file
    done
}

mkdir -p $logDir $pDumpDir $sDumpDir
mainProc | tee "$logDir/mylog.txt"

