package com.yg.osswitch;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

/**
 * Switch 双系统切换（Android 端）
 *
 * 原理：hekate 重启时复用「上次启动项的编号」(REBOOT_REASON_SELF)。
 * 把当前系统所在的 ini 文件内容换成目标系统，重启后同一编号即加载目标系统，
 * 跳过 hekate 菜单；另一个 ini 保留另一系统，冷启动时菜单两个都在。
 */
public class MainActivity extends Activity {

    private static final String UBU_MARK = "ubuntu-jammy";

    private static final String ANDROID_TPL =
            "[LineageOS]\r\n" +
            "l4t=1\r\n" +
            "boot_prefixes=switchroot/android/\r\n" +
            "id=%ID%\r\n" +
            "icon=switchroot/android/icon_android_hue.bmp\r\n" +
            "logopath=switchroot/android/bootlogo_android.bmp\r\n" +
            "r2p_action=self\r\n";

    private static final String UBUNTU_TPL =
            "[L4T Ubuntu Jammy]\r\n" +
            "l4t=1\r\n" +
            "boot_prefixes=/switchroot/ubuntu-jammy/\r\n" +
            "id=%ID%\r\n" +
            "icon=switchroot/ubuntu-jammy/icon_ubuntu_hue.bmp\r\n" +
            "logopath=switchroot/ubuntu-jammy/bootlogo_ubuntu.bmp\r\n" +
            "r2p_action=self\r\n";

    private TextView logView;
    private final Handler ui = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(buildUi());
        refreshState();
    }

    private View buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(56, 32, 56, 24);

        TextView title = new TextView(this);
        title.setText("Switch 系统切换");
        title.setTextSize(26);
        title.setGravity(Gravity.CENTER);
        root.addView(title);

        root.addView(button("重启到 Ubuntu (Linux)", 22, () ->
                confirm("重启到 Ubuntu",
                        "重启后约 3 秒直接进入 Ubuntu，不停在 hekate。\n（Ubuntu 仍保留在 hekate 菜单里）",
                        "ubuntu")));

        root.addView(button("重启到 Android", 22, () ->
                confirm("重启到 Android",
                        "重启后约 3 秒直接进入 Android，不停在 hekate。\n（Android 仍保留在 hekate 菜单里）",
                        "android")));

        root.addView(button("重启到 hekate 菜单", 18, () ->
                confirm("重启到 hekate 菜单",
                        "恢复两个启动项后重启，进入 hekate 选择界面。", "menu")));

        logView = new TextView(this);
        logView.setTextSize(13);
        logView.setPadding(0, 20, 0, 0);
        ScrollView sc = new ScrollView(this);
        sc.addView(logView);
        root.addView(sc);

        return root;
    }

    private Button button(String text, int size, Runnable action) {
        Button b = new Button(this);
        b.setText(text);
        b.setTextSize(size);
        b.setAllCaps(false);
        b.setOnClickListener(v -> action.run());
        return b;
    }

    private void confirm(String title, String msg, final String target) {
        new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(msg)
                .setNegativeButton("取消", null)
                .setPositiveButton("重启", (d, w) -> new Thread(() -> doSwitch(target)).start())
                .show();
    }

    private void refreshState() {
        new Thread(() -> {
            String dir = iniDir();
            if (dir == null) { log("❌ 找不到 SD 卡 bootloader/ini（root 权限？）"); return; }
            log("启动项目录：" + dir);
            log(runSu("ls " + dir));
            log(runSu("for f in " + dir + "/*.ini; do echo \"--- $f\"; head -3 \"$f\"; done"));
        }).start();
    }

    private void doSwitch(String target) {
        String dir = iniDir();
        if (dir == null) { log("❌ 找不到 ini 目录"); return; }

        if ("menu".equals(target)) {
            writeTpl(dir + "/android.ini", ANDROID_TPL.replace("%ID%", "SWANDR"));
            writeTpl(dir + "/L4T-jammy.ini", UBUNTU_TPL.replace("%ID%", "SWR-JAM"));
            log("已恢复两个启动项");
            log("重启，进入 hekate 菜单 ...");
            runSu("reboot");
            return;
        }

        // 定位「当前系统」文件：Android 端运行时，含 ubuntu-jammy 的是 Ubuntu 项
        String cur = null, other = null;
        String listing = runSu("ls " + dir);
        for (String name : listing.split("\n")) {
            name = name.trim();
            if (!name.endsWith(".ini")) continue;
            String path = dir + "/" + name;
            boolean isUbu = runSu("grep -q " + UBU_MARK + " " + path + " && echo YES || echo NO").contains("YES");
            if (isUbu) { if (other == null) other = path; }
            else if (cur == null) cur = path;
        }

        if (cur == null) { log("❌ 找不到 Android 启动项文件"); return; }
        if (other == null) other = dir + "/L4T-jammy.ini";

        // 切换：两个 ini 都写成目标系统（hekate 无论按 id 还是按位置都会进目标）
        boolean toUbu = "ubuntu".equals(target);
        String tpl = toUbu ? UBUNTU_TPL : ANDROID_TPL;
        String canonicalId = toUbu ? "SWR-JAM" : "SWANDR";
        writeTpl(cur, tpl.replace("%ID%", canonicalId));
        writeTpl(other, tpl.replace("%ID%", canonicalId));
        log("两个启动项都已设为 " + target + "（id=" + canonicalId + "）");
        log("重启 ...");
        runSu("sync; reboot");
    }

    /** 写模板：先写到自己 cache，再用 su 复制过去（绕过存储权限） */
    private void writeTpl(String destPath, String content) {
        try {
            File f = new File(getCacheDir(), "tpl.ini");
            FileOutputStream fos = new FileOutputStream(f);
            fos.write(content.getBytes(StandardCharsets.US_ASCII));
            fos.close();
            runSu("cp " + f.getAbsolutePath() + " " + destPath + " && chmod 666 " + destPath);
            log("已写入 " + destPath);
        } catch (Exception e) {
            log("写入失败: " + e);
        }
    }

    private String iniDir() {
        String out = runSu("ls -d /storage/*/bootloader/ini 2>/dev/null");
        for (String l : out.split("\n")) {
            l = l.trim();
            if (l.endsWith("/bootloader/ini")) return l;
        }
        return null;
    }

    private String runSu(String cmd) {
        try {
            Process p = Runtime.getRuntime().exec(new String[]{"su", "-c", cmd});
            BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line).append('\n');
            br.close();
            p.waitFor();
            return sb.toString().trim();
        } catch (Exception e) {
            return "执行失败: " + e;
        }
    }

    private void log(final String s) {
        ui.post(() -> { if (logView != null) logView.append(s + "\n"); });
    }
}
