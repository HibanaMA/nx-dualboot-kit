# Switch 双系统（Android 15 + Ubuntu 22.04）+ 一键切换 完整手册

> 面向：Nintendo Switch 初代（Erista / 可 RCM）
> 结果：一张 128GB SD 卡同时装 Android 15 与 Ubuntu 22.04，两边都能一键切换，无需碰 hekate 界面。

---

## 一、下载链接汇总

| 用途 | 地址 |
|---|---|
| **hekate 引导器** | https://github.com/CTCaer/hekate/releases |
| **LineageOS 22.2（Android 15）** | https://download.lineageos.org/devices/nx_tab |
| **LineageOS 单包直链（当前版本）** | https://mirrorbits.lineageos.org/full/nx_tab/20261115/ |
| **GApps（MindTheGapps 15 arm64）** | https://github.com/MindTheGapps/15.0.0-arm64/releases |
| **Magisk** | https://github.com/topjohnwu/Magisk/releases |
| **Ubuntu Jammy（L4S）** | https://download.switchroot.org/ubuntu-jammy/ |
| **Ubuntu Noble（24.04，可选）** | https://download.switchroot.org/ubuntu-noble/ |
| **RCM 注入（网页版）** | https://switch.exploit.fortheusers.org/ |
| **TegraRcmGUI（Windows 注入器）** | https://github.com/eliboa/TegraRcmGUI/releases |
| **hekate / Ubuntu 官方文档** | https://wiki.switchroot.org/wiki/linux/l4t-ubuntu-jammy-installation-guide |
| **LineageOS 官方安装指引** | https://wiki.lineageos.org/devices/nx_tab/install/variant1 |

---

## 二、准备

- Switch 初代（HAC-001，可 RCM），或已硬破的机型
- microSD 卡 ≥ 64GB（本方案用 128GB）
- RCM 短接器（jig）+ 数据线（**必须是数据线**，原装线只充电）
- PC（Windows，装有 7-Zip、adb）

---

## 三、分区（会清空整卡）

`hekate → Tools → Partition SD card → Next Step`

| 分区 | 大小 | 说明 |
|---|---|---|
| FAT32 | 剩余（约 49GB） | 两个系统共享的文件区 |
| Android system | 2GB（自动） | |
| **Android USER** | **32GB** | 应用数据 |
| **Linux EXT4** | **32GB** | Ubuntu 根分区 |

⚠️ Android 分区类型选 **Dynamic（Android 13+）** —— Android 15 只支持动态分区。
⚠️ Linux 滑块必须 ≥ 16GB，否则后面 `Flash Linux` 会失败。

---

## 四、安装 Android 15（LineageOS 22.2）

### 1. 拷贝文件到 FAT32（hekate → Tools → USB Tools → SD Card）

```
SD 根目录
├── bootloader\            ← hekate 压缩包解压
├── switchroot\
│   ├── android\           ← bl31.bin bl33.bin boot.scr 图标
│   └── install\           ← boot.img recovery.img nx-plat.dtimg
├── lineage-22.2-....zip
├── MindTheGapps-15.0.0-arm64.zip
└── Magisk.apk
```

`bl31.bin / bl33.bin / boot.scr / boot.img / recovery.img / nx-plat.dtimg` 都在 LineageOS 单包目录里可直接下载。

### 2. 刷入

```
hekate → Tools → Flash Android 13+
   → 它会格式化动态分区并重启进 Recovery（问是否重启时选 Yes）
Recovery：
   Factory reset → Format data
   Apply update → Apply from ADB（或从 SD 卡）
      → lineage-22.2-....zip
      → MindTheGapps-15.0.0-arm64.zip
   Reboot system
```

首次启动 5~15 分钟。

### 3. 拿 root（Magisk）

```
1) 装 Magisk.apk
2) Magisk → 安装 → 选择并修补一个文件 → 选 SD 上的 switchroot/install/boot.img
3) 生成的 magisk_patched-*.img 覆盖回 switchroot/install/boot.img（先备份原版）
4) （可选，更稳）在 Recovery 里 Apply update → 选 Magisk.zip（APK 改名）
```

Magisk v31 起**不再弹授权框**，root 要在「超级用户」页手动勾选应用。

---

## 五、安装 Ubuntu 22.04（L4S Jammy）

### 1. 下载并解压

从 https://download.switchroot.org/ubuntu-jammy/ 下载 `.7z`，**解压到 FAT32 根目录**（不要多套一层文件夹）。

解压后应出现：

```
switchroot\install\l4t.00   (~4GB)
switchroot\install\l4t.01   (~1.6GB)
switchroot\ubuntu-jammy\    uImage / initramfs / boot.scr / bl31 / bl33 / dtimg / 图标
bootloader\ini\L4T-jammy.ini
```

### 2. Flash Linux

```
hekate → Tools → Flash Linux
   （把 l4t.00/.01 写进 EXT4 分区，约 3~8 分钟）
```

⚠️ 这一步要求 hekate ≥ 6.0.6。

### 3. 启动与首次配置

```
hekate → More Configs → [L4T Ubuntu Jammy]
默认账号：ubuntu / ubuntu
```

装完后这两个安装分卷可以删掉，腾出 5.8GB：

```
switchroot\install\l4t.00
switchroot\install\l4t.01
```

### 4. 首次进系统建议做的三件事

```bash
# 改密码
passwd

# 装 SSH
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable --now ssh
ip -4 addr show | grep inet

# 挂共享盘（49GB FAT32）
sudo mkdir -p /mnt/share
echo '/dev/mmcblk0p1 /mnt/share vfat uid=1000,gid=1000,utf8,umask=000,nofail 0 0' | sudo tee -a /etc/fstab
sudo mount -a

# 中文输入法
sudo apt install -y fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-qt5 fcitx5-config-qt
im-config -n fcitx5
# ~/.profile 追加：
#   export GTK_IM_MODULE=fcitx
#   export QT_IM_MODULE=fcitx
#   export XMODIFIERS=@im=fcitx
```

---

## 六、双系统一键切换（本项目核心）

### 1. 原理

hekate 重启时把「重启原因 + 启动项标识」写进 max77620 RTC，回来时按这些信息决定启动哪一项。实践中最稳的用法是：

```
切换时：把 bootloader/ini 下的**两个** ini 都写成目标系统
        （无论 hekate 按 id 还是按位置匹配，都会进目标）
重启：  3 秒 bootwait 后直接进目标系统，不停菜单
开机后：由脚本自动把两个 ini 恢复成「一项 Android、一项 Ubuntu」
冷启动：从 RCM 注入 hekate，菜单里两个系统都在，可自由选择
```

### 2. hekate 配置文件结构

`bootloader/hekate_ipl.ini`（只管全局配置）：

```ini
[config]
autoboot=0
autoboot_list=1
bootwait=3
customlogo=0
verification=1
backlight=100
autohosoff=0
autonogc=1
```

`bootloader/ini/android.ini`：

```ini
[LineageOS]
l4t=1
boot_prefixes=switchroot/android/
id=SWANDR
icon=switchroot/android/icon_android_hue.bmp
logopath=switchroot/android/bootlogo_android.bmp
r2p_action=self
```

`bootloader/ini/L4T-jammy.ini`：

```ini
[L4T Ubuntu Jammy]
l4t=1
boot_prefixes=/switchroot/ubuntu-jammy/
id=SWR-JAM
icon=switchroot/ubuntu-jammy/icon_ubuntu_hue.bmp
logopath=switchroot/ubuntu-jammy/bootlogo_ubuntu.bmp
r2p_action=self
```

⚠️ **必须 CRLF 换行**，LF 会让 hekate 解析失败（表现为「启动项消失」）。
⚠️ 两个 `id=` 必须不同（`SWANDR` / `SWR-JAM`）。

### 3. Android 侧

**应用：系统切换（`com.yg.osswitch`）**

三个按钮，每个点击后弹确认框：

| 按钮 | 行为 |
|---|---|
| 重启到 Ubuntu (Linux) | 两个 ini 写成 Ubuntu → reboot |
| 重启到 Android | 两个 ini 写成 Android → reboot |
| 重启到 hekate 菜单 | 恢复标准双项 → reboot（进 hekate 菜单） |

实现要点：
- 全部走 `su -c`，不需要存储权限
- ini 内容以模板常量写进 App 私有 cache，再用 `su cp` 复制到 SD
- 写入时保留/设置规范 id（Android=`SWANDR`，Ubuntu=`SWR-JAM`）

**APK 位置**：`D:\BOOKWALKER\提取工具5_Switch\系统切换.apk`（约 17KB）

**手工编译方式（无 Gradle）**：

```powershell
# 依赖：Android SDK build-tools 34、platforms/android-34、Android Studio 自带 JBR
aapt2 compile --dir res -o compiled.zip
aapt2 link -o base.apk -I android.jar --manifest AndroidManifest.xml -R compiled.zip --auto-add-overlay
javac --release 11 -encoding UTF-8 -classpath android.jar -d classes src\com\yg\osswitch\MainActivity.java
d8 --lib android.jar --min-api 29 --output . classes\com\yg\osswitch\*.class
# 把 classes.dex 塞进 base.apk → zipalign -f 4 → apksigner sign
```

源码：`D:\BOOKWALKER\apk_switch\`

### 4. Ubuntu 侧

| 路径 | 作用 |
|---|---|
| `/usr/local/bin/switch-os` | `switch-os android\|ubuntu\|menu`：写 ini + 重启 |
| `/usr/local/bin/restore-ini.sh` | 把两个 ini 恢复成标准双项 |
| `/etc/systemd/system/switch-restore.service` | 开机自动执行 restore（已 enable） |
| `/usr/local/share/switch/{android,ubuntu}.ini` | 两个模板 |
| `/usr/local/share/switch/icons/*.png` | 桌面图标 |
| `/etc/sudoers.d/switch-os` | `<你的用户名> ALL=(ALL) NOPASSWD: /usr/local/bin/switch-os` |

桌面图标（2 个）：

- **重启到 Android** → `sudo /usr/local/bin/switch-os android`
- **重启到 hekate 菜单** → `sudo /usr/local/bin/switch-os menu`

### 5. 开机自动恢复 ini

**Android**：`/data/adb/service.d/restore-ini.sh`（Magisk 开机脚本，root 权限，延迟 45 秒执行）

**Ubuntu**：`switch-restore.service`（oneshot，`WantedBy=multi-user.target`）

作用：保证每次启动完成后，SD 上的 ini 都是干净的标准双项，冷启动时菜单可自由选择。

### 6. 开机自动 TCP adb（可选）

`/data/adb/service.d/adbtcp.sh`：

```sh
#!/system/bin/sh
sleep 25
setprop service.adb.tcp.port 5555
settings put global adb_enabled 1
stop adbd; sleep 1; start adbd
```

之后每次开机直接 `adb connect <Switch_IP>:5555`，不用再去开发者选项点无线调试。

---

## 七、常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| hekate 菜单里启动项消失 | ini 是 LF 换行 | 改用 CRLF 重写 |
| 切换后还是回到原系统 | 两个 ini 的 id 相同 / 内容没换 | 执行「重启到 hekate 菜单」恢复标准双项 |
| 一键切换后进 hekate 菜单 | ini 内容缺失或路径错误 | 检查 `boot_prefixes` |
| Flash Linux 报找不到分区 | 分区时没给 Linux 留空间 | 重新分区（清卡） |
| Android 卡 logo | 分区选了 Legacy | 重新分区选 Dynamic |
| adb 连不上 | adbd 没监听 / IP 变了 | 查 IP；确认 `persist.adb.tcp.port=5555` |
| 无线调试重启后关闭 | 属正常，UI 开关不持久 | 用 TCP adb（`persist.adb.tcp.port`） |
| Ubuntu 首次启动卡 logo | 卷标不是 `SWR-JAM` | 检查 ini 的 `id=SWR-JAM` 与分区标签 |
| 想临时停在 hekate | — | 开机时按住 **音量－** |

---

## 八、实测记录

```
✅ Android → Ubuntu（应用按钮，3 秒自动进 Ubuntu）
✅ Ubuntu → Android（桌面图标，3 秒自动进 Android）
✅ 每次开机自动恢复双项，冷启动菜单两个系统都在
✅ TCP adb 开机自动可用（5555）
⚠️ 踩过的坑：ini 用 LF 写 → hekate 不认；两个 ini 的 id 相同 → 切换无效
```

---

## 九、日常使用速查

| 想做的事 | 操作 |
|---|---|
| 从 Android 去 Ubuntu | 打开「系统切换」→ 重启到 Ubuntu |
| 从 Ubuntu 去 Android | 桌面「重启到 Android」 |
| 回 hekate 菜单（临时选系统） | 任一端点「重启到 hekate 菜单」，或开机按住音量－ |
| 远程连 Android | `adb connect <IP>:5555` |
| 远程连 Ubuntu | `ssh <用户名>@<IP>`（已配免密密钥） |
| 两个系统共享文件 | Android：`/storage/XXXX-XXXX`；Ubuntu：`/mnt/share` |
| 进 RCM | 关机 + 短接 + 音量+ + 电源 |
