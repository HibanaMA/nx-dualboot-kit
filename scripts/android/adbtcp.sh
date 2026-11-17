#!/system/bin/sh
# Switch: 寮€鏈鸿嚜鍔ㄥ惎鐢?TCP adb (5555)
# 瀹夎浣嶇疆: /data/adb/service.d/adbtcp.sh   (Magisk 寮€鏈鸿剼鏈? root 鏉冮檺)
# 浣滅敤: 涓嶇敤鍐嶅幓 寮€鍙戣€呴€夐」 鈫?鏃犵嚎璋冭瘯 鎵嬪姩寮€鍏筹紝寮€鏈哄悗鐩存帴
#       adb connect <Switch_IP>:5555
sleep 25

setprop service.adb.tcp.port 5555
settings put global adb_enabled 1
settings put global development_settings_enabled 1

stop adbd
sleep 1
start adbd

log -t OSswitch "adbd TCP 5555 started"
