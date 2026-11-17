#!/bin/bash
# Switch: 寮€鏈哄悗鎶?hekate 鍚姩椤规仮澶嶆垚鏍囧噯鍙岄」锛圓ndroid + Ubuntu锛?# 鐩殑锛氬喎鍚姩锛圧CM 娉ㄥ叆 hekate锛夋椂鑿滃崟閲屼袱涓郴缁熼兘鍦ㄣ€?set -e

SHARE=/mnt/share
INI_DIR="$SHARE/bootloader/ini"

mountpoint -q "$SHARE" || mount /dev/mmcblk0p1 "$SHARE" 2>/dev/null || exit 0
mkdir -p "$INI_DIR"

# 宸茬粡鏄爣鍑嗗弻椤瑰氨璺宠繃锛堥伩鍏嶆棤璋撳啓鐩橈級
if [ -f "$INI_DIR/android.ini" ] && [ -f "$INI_DIR/L4T-jammy.ini" ] && \
   grep -q "switchroot/android" "$INI_DIR/android.ini" 2>/dev/null && \
   grep -q "ubuntu-jammy" "$INI_DIR/L4T-jammy.ini" 2>/dev/null && \
   [ "$(ls "$INI_DIR"/*.ini | wc -l)" -eq 2 ]; then
    exit 0
fi

printf '[LineageOS]\r\nl4t=1\r\nboot_prefixes=switchroot/android/\r\nid=SWANDR\r\nicon=switchroot/android/icon_android_hue.bmp\r\nlogopath=switchroot/android/bootlogo_android.bmp\r\nr2p_action=self\r\n' > "$INI_DIR/android.ini"
printf '[L4T Ubuntu Jammy]\r\nl4t=1\r\nboot_prefixes=/switchroot/ubuntu-jammy/\r\nid=SWR-JAM\r\nicon=switchroot/ubuntu-jammy/icon_ubuntu_hue.bmp\r\nlogopath=switchroot/ubuntu-jammy/bootlogo_ubuntu.bmp\r\nr2p_action=self\r\n' > "$INI_DIR/L4T-jammy.ini"

for f in "$INI_DIR"/*.ini; do
    case "$(basename "$f")" in
        android.ini|L4T-jammy.ini) ;;
        *) rm -f "$f" ;;
    esac
done

sync
logger -t os-switch "hekate 鍚姩椤瑰凡鎭㈠涓烘爣鍑嗗弻椤?
