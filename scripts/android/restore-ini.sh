#!/system/bin/sh
# Switch: 寮€鏈哄悗鎶?hekate 鍚姩椤规仮澶嶆垚鏍囧噯鍙岄」锛圓ndroid + Ubuntu锛?# 瀹夎浣嶇疆: /data/adb/service.d/restore-ini.sh   (Magisk 寮€鏈鸿剼鏈? root 鏉冮檺)
# 浣滅敤: 鍒囨崲绯荤粺鏃朵袱涓?ini 浼氳涓存椂鍐欐垚鍚屼竴鐩爣锛涘紑鏈哄悗鎭㈠鎴愩€屼竴椤?Android銆佷竴椤?Ubuntu銆嶏紝
#       杩欐牱浠?RCM 鍐峰惎鍔?hekate 鏃惰彍鍗曢噷涓や釜绯荤粺閮藉湪銆?sleep 45

INI_DIR=""
for d in /storage/*/bootloader/ini; do
  [ -d "$d" ] && INI_DIR="$d" && break
done
[ -n "$INI_DIR" ] || exit 0

A="$INI_DIR/android.ini"
U="$INI_DIR/L4T-jammy.ini"

# 宸茬粡鏄爣鍑嗗弻椤瑰氨璺宠繃
if grep -q "ubuntu-jammy" "$A" 2>/dev/null && ! grep -q "ubuntu-jammy" "$U" 2>/dev/null \
   && [ "$(ls "$INI_DIR"/*.ini 2>/dev/null | wc -l)" -eq 2 ]; then
  exit 0
fi

printf '[LineageOS]\r\nl4t=1\r\nboot_prefixes=switchroot/android/\r\nid=SWANDR\r\nicon=switchroot/android/icon_android_hue.bmp\r\nlogopath=switchroot/android/bootlogo_android.bmp\r\nr2p_action=self\r\n' > "$A"
printf '[L4T Ubuntu Jammy]\r\nl4t=1\r\nboot_prefixes=/switchroot/ubuntu-jammy/\r\nid=SWR-JAM\r\nicon=switchroot/ubuntu-jammy/icon_ubuntu_hue.bmp\r\nlogopath=switchroot/ubuntu-jammy/bootlogo_ubuntu.bmp\r\nr2p_action=self\r\n' > "$U"

for f in "$INI_DIR"/*.ini; do
  case "$(basename "$f")" in
    android.ini|L4T-jammy.ini) ;;
    *) rm -f "$f" ;;
  esac
done

sync
log -t OSswitch "hekate boot entries restored"
