# 一键编译 + 安装 APK
$ErrorActionPreference = 'Stop'
$sdk  = 'C:\Android\sdk'
$bt   = "$sdk\build-tools\34.0.0"
$jb   = 'C:\Program Files\Android\Android Studio\jbr'
$aj   = "$sdk\platforms\android-34\android.jar"
$proj = '$(Get-Location)'
$adb  = "$sdk\platform-tools\adb.exe"
$dev  = '<SWITCH_IP>:5555'
$env:JAVA_HOME = $jb
Set-Location $proj

Write-Host '[1/6] aapt2 compile'
if (Test-Path compiled.zip) { Remove-Item compiled.zip -Force }
& "$bt\aapt2.exe" compile --dir res -o compiled.zip
if ($LASTEXITCODE -ne 0) { throw 'aapt2 compile 失败' }

Write-Host '[2/6] aapt2 link'
if (Test-Path base.apk) { Remove-Item base.apk -Force }
& "$bt\aapt2.exe" link -o base.apk -I $aj --manifest AndroidManifest.xml -R compiled.zip --auto-add-overlay
if ($LASTEXITCODE -ne 0) { throw 'aapt2 link 失败' }

Write-Host '[3/6] javac'
Remove-Item classes -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force classes | Out-Null
$srcs = Get-ChildItem -Recurse -Filter *.java src | ForEach-Object { $_.FullName }
& "$jb\bin\javac.exe" --release 11 -encoding UTF-8 -classpath $aj -d classes $srcs
if ($LASTEXITCODE -ne 0) { throw 'javac 失败' }

Write-Host '[4/6] d8'
Remove-Item classes.dex -Force -ErrorAction SilentlyContinue
$classes = Get-ChildItem -Recurse -Filter *.class classes | ForEach-Object { $_.FullName }
& "$bt\d8.bat" --lib $aj --min-api 29 --output . $classes
if ($LASTEXITCODE -ne 0) { throw 'd8 失败' }

Write-Host '[5/6] 打包 + 对齐'
Copy-Item base.apk app-unsigned.apk -Force
$py = 'python'
$code = @'
import zipfile, shutil
shutil.copyfile(r'$(Get-Location)\app-unsigned.apk', r'$(Get-Location)\app-unsigned2.apk')
with zipfile.ZipFile(r'$(Get-Location)\app-unsigned2.apk','a',zipfile.ZIP_DEFLATED) as z:
    z.write(r'$(Get-Location)\classes.dex','classes.dex')
print('dex ok')
'@
[IO.File]::WriteAllText("$proj\_pack.py", $code, (New-Object Text.UTF8Encoding($false)))
& $py "$proj\_pack.py"
& "$bt\zipalign.exe" -f 4 app-unsigned2.apk app-aligned.apk

Write-Host '[6/6] 签名 + 安装'
& "$bt\apksigner.bat" sign --ks "$proj\debug.keystore" --ks-pass pass:android --key-pass pass:android --out OSswitch.apk app-aligned.apk
if ($LASTEXITCODE -ne 0) { throw 'apksigner 失败' }
Write-Host ("APK: " + [math]::Round((Get-Item "$proj\OSswitch.apk").Length / 1KB) + " KB")

& $adb connect $dev | Out-Null
& $adb -s $dev install -r "$proj\OSswitch.apk"
$uid = if ((& $adb -s $dev shell "cmd package list packages -U | grep osswitch") -match 'uid:(\d+)') { $Matches[1] }
if ($uid) {
    & $adb -s $dev shell "su -c 'magisk --sqlite \"REPLACE INTO policies (uid, policy, until, logging, notification) VALUES ($uid, 2, 0, 1, 1)\"'"
    Write-Host "已授权 root: uid=$uid"
}
