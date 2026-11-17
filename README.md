# nx-dualboot-kit

Nintendo Switch 初代（Erista）**Android 15 + Ubuntu 22.04 双系统**，带**一键切换**（不停 hekate 菜单），以及开机自动恢复启动项、开机自动 TCP adb。

> One-tap dual-boot switcher for the original Nintendo Switch (Android 15 / LineageOS 22.2 + Ubuntu 22.04 L4S).
> Switching writes both hekate boot entries to the target OS, then a boot-time service restores the standard two-entry menu — so cold booting from RCM still lets you pick either OS.

---

## 效果

| 操作 | 结果 |
|---|---|
| Android 里点「重启到 Ubuntu」 | 3 秒后直接进 Ubuntu，不停 hekate |
| Ubuntu 桌面点「重启到 Android」 | 3 秒后直接进 Android |
| 任一端点「重启到 hekate 菜单」 | 恢复两项后进 hekate，可手动选 |
| 从 RCM 冷启动 | hekate 菜单里 Android / Ubuntu 都在 |
| 开机后 | `adb connect <IP>:5555` 直接可用，无需开无线调试 |

---

## 原理

hekate 重启时会复用「上次启动项」的信息（`REBOOT_REASON_SELF`，配合 `BOOT_CFG_FROM_ID` / `autoboot_idx`）。实测最稳的用法：

```
切换时  → 把 bootloader/ini 下的两个 ini 都写成目标系统
          （无论 hekate 按 id 还是按位置匹配，都会进目标）
重启时  → bootwait=3 后直接进目标系统
开机后  → restore-ini 把两个 ini 恢复成「一项 Android、一项 Ubuntu」
冷启动  → 从 RCM 注入 hekate，菜单两项都在
```

关键细节（踩过的坑）：

- ini **必须 CRLF 换行**，LF 会导致 hekate 解析失败（表现为「启动项消失」）
- 两个 ini 的 `id=` **必须不同**（`SWANDR` / `SWR-JAM`），相同会导致切换无效

---

## 仓库结构

```
docs/switch-dual-boot-guide.zh-CN.md   完整中文手册（下载链接、装机、切换、排错）
app/                                   Android 切换应用源码 + 已签名 APK
  src/com/yg/osswitch/MainActivity.java
  res/  AndroidManifest.xml  build.ps1
  OSswitch.apk                         直接安装（约 17KB）
scripts/android/restore-ini.sh         Magisk 开机脚本：恢复启动项
scripts/android/adbtcp.sh              Magisk 开机脚本：开机启用 TCP adb
scripts/ubuntu/switch-os               Ubuntu 端切换脚本
scripts/ubuntu/restore-ini.sh          Ubuntu 端恢复脚本
scripts/ubuntu/switch-restore.service  systemd 服务（开机自动恢复）
templates/android.ini                  启动项模板
templates/ubuntu.ini
```

---

## 快速安装

### Android 端

```bash
# 1) 安装应用（需 Magisk root）
adb install app/OSswitch.apk

# 2) 开机脚本
adb push scripts/android/restore-ini.sh /data/local/tmp/
adb push scripts/android/adbtcp.sh     /data/local/tmp/
adb shell su -c 'mkdir -p /data/adb/service.d'
adb shell su -c 'cp /data/local/tmp/restore-ini.sh /data/adb/service.d/ && chmod 755 /data/adb/service.d/restore-ini.sh'
adb shell su -c 'cp /data/local/tmp/adbtcp.sh /data/adb/service.d/ && chmod 755 /data/adb/service.d/adbtcp.sh'

# 3) 给应用 root（Magisk v31 起不再弹窗，需手动授权或用 sqlite 写策略）
```

### Ubuntu 端

```bash
sudo cp scripts/ubuntu/switch-os              /usr/local/bin/ && sudo chmod 755 /usr/local/bin/switch-os
sudo cp scripts/ubuntu/restore-ini.sh         /usr/local/bin/ && sudo chmod 755 /usr/local/bin/restore-ini.sh
sudo cp scripts/ubuntu/switch-restore.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now switch-restore.service

# 免密（把 <user> 换成你的用户名）
echo '<user> ALL=(ALL) NOPASSWD: /usr/local/bin/switch-os' | sudo tee /etc/sudoers.d/switch-os
sudo chmod 440 /etc/sudoers.d/switch-os

# 模板目录
sudo mkdir -p /usr/local/share/switch
sudo cp templates/*.ini /usr/local/share/switch/
```

桌面图标（`.desktop`，`Exec=sudo /usr/local/bin/switch-os android` / `menu`）请参考手册第六章。

---

## 编译 APK（无需 Gradle）

```powershell
# 依赖：Android SDK build-tools 34 + platforms;android-34 + JDK 17
cd app
.\build.ps1     # 或参考手册第六章的手工步骤
```

---

## 系统镜像下载

| 用途 | 地址 |
|---|---|
| hekate | https://github.com/CTCaer/hekate/releases |
| LineageOS 22.2 (Android 15, nx_tab) | https://download.lineageos.org/devices/nx_tab |
| GApps (MindTheGapps 15 arm64) | https://github.com/MindTheGapps/15.0.0-arm64/releases |
| Magisk | https://github.com/topjohnwu/Magisk/releases |
| Ubuntu Jammy (L4S) | https://download.switchroot.org/ubuntu-jammy/ |
| Ubuntu Noble (24.04) | https://download.switchroot.org/ubuntu-noble/ |
| RCM 网页注入 | https://switch.exploit.fortheusers.org/ |
| Switchroot Wiki | https://wiki.switchroot.org/ |

---

## 验证环境

```
Switch 初代 (Erista, unpatched)
Android 15 / LineageOS 22.2 (nx_tab, 20261115)
Ubuntu 22.04.5 LTS (L4S Jammy, kernel 4.9.140-l4t)
hekate 6.5.5 + Nyx 1.9.5
Magisk 31.1
SD: 128GB → FAT32 ~49GB / Android USER 32GB / Linux EXT4 32GB
```

---

## 免责

仅供个人设备与学习研究使用。修改分区、刷写系统有数据丢失风险，操作前请备份；一切后果自负。
本项目与 Nintendo / KADOKAWA / BOOK☆WALKER / LineageOS / switchroot 无任何关联。

## License

MIT
