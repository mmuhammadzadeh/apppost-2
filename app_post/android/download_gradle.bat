@echo off
echo 手动下载 Gradle...
echo Manually downloading Gradle...

REM Create gradle wrapper directory if it doesn't exist
if not exist "%USERPROFILE%\.gradle\wrapper\dists" mkdir "%USERPROFILE%\.gradle\wrapper\dists"

REM Download Gradle from Huawei Cloud mirror
echo 从华为云镜像下载 Gradle...
powershell -Command "& {Invoke-WebRequest -Uri 'https://mirrors.huaweicloud.com/gradle/gradle-8.12-all.zip' -OutFile '%USERPROFILE%\.gradle\wrapper\dists\gradle-8.12-all.zip'}"

if exist "%USERPROFILE%\.gradle\wrapper\dists\gradle-8.12-all.zip" (
    echo Gradle 下载成功！
    echo Gradle downloaded successfully!
) else (
    echo Gradle 下载失败，请检查网络连接
    echo Gradle download failed, please check network connection
)

pause
