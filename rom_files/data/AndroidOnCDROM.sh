imgs=("")
find_path="/sdcard/"
iso_num=0
find_iso(){
echo "please select mount file"
find_imgs=$(find $find_path -name "*.iso" -o -name "*.img")
count=0
nn=0
for img_path in $find_imgs
do
	F_SIZE=$(ls -l $img_path | cut -d' ' -f5)
	if [ -f "$img_path" -a "$F_SIZE" != "0" ] 
	then
		nn=$((count++))
		imgs[$nn]=$img_path
		echo "$nn -- $img_path"

	fi
done
}

mount_iso(){
iso_path=${imgs[$iso_num]}
echo "file path : $iso_path"
if [ "$iso_path" == "" ]
then
	echo "please input 0 ~ $((${#imgs[@]}-1))"
	menu
else
	CONFIG_USB_PATH="/config/usb_gadget/g1"
	CONFIG_USB_PATH2="/sys/class/android_usb/android0"
	if [ -d "$CONFIG_USB_PATH" ]
	then
		cd $CONFIG_USB_PATH
		conf_path=$(find ./ -name configu*)
		echo "conf_path ::: $conf_path"
		if [ "$conf_path" != "" ]
		then
			echo -n 'msc' > "$conf_path"
			for f in configs/b.1/f*; do rm $f; done
			ln -s functions/mass_storage.0 configs/b.1/f1
			echo -n "$iso_path" > configs/b.1/f1/lun.0/file
			#echo "$CONFIG_USB_PATH OK !!!"
		fi	
	elif [ -d "$CONFIG_USB_PATH2" ]
	then
		cd $CONFIG_USB_PATH2
		echo -n 0 >enable
		echo -n '$iso_path' >f_mass_storage/lun/file
		echo -n 'mass_storage' >functions
		echo -n 1 >enable
		#echo "$CONFIG_USB_PATH2 OK !!!"
	else
		echo "this device not support..."
		exit 1;
	fi
	echo "mount $iso_path ok !!!"
	echo "===== Unplug can exit ======="
fi
}

menu(){
find_iso
echo "q -- quit"
echo ": "
read  iso_num
if [ "$iso_num" == "q" ]
then
	exit 0;
else
	mount_iso 
fi
}

main(){
clear
UUUUID=$(id -u)
if [ "$UUUUID" == "0" ]
then
	menu
else
	echo "need root user run $0"
	exit 1;
fi
}
main

