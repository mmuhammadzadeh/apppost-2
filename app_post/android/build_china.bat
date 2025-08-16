@echo off
echo 正在使用中国镜像配置构建项目...
echo Building project with Chinese mirror configuration...

REM Set environment variables for Chinese mirrors
set GRADLE_OPTS=-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.configureondemand=true

REM Clean and build
echo 清理项目...
call gradlew clean

echo 开始构建...
call gradlew build --refresh-dependencies

if %ERRORLEVEL% EQU 0 (
    echo 构建完成！
    echo Build completed!
) else (
    echo 构建失败，尝试使用备用方法...
    echo Build failed, trying alternative method...
    
    REM Try with offline mode if dependencies are already downloaded
    call gradlew build --offline
)

pause
