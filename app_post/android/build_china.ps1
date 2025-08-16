Write-Host "正在使用中国镜像配置构建项目..." -ForegroundColor Green
Write-Host "Building project with Chinese mirror configuration..." -ForegroundColor Green

# Set environment variables for Chinese mirrors
$env:GRADLE_OPTS = "-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.configureondemand=true"

# Clean and build
Write-Host "清理项目..." -ForegroundColor Yellow
./gradlew clean

Write-Host "开始构建..." -ForegroundColor Yellow
./gradlew build --refresh-dependencies

Write-Host "构建完成！" -ForegroundColor Green
Write-Host "Build completed!" -ForegroundColor Green
Read-Host "按任意键继续..."
