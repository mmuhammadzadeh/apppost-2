# 中国用户构建指南 (Chinese User Build Guide)

## 问题说明 (Problem Description)
在中国大陆地区，由于网络限制，Gradle 下载依赖包时经常会遇到连接超时或下载失败的问题。

## 解决方案 (Solution)
本项目已配置中国镜像源，使用阿里云和腾讯云的镜像来加速下载。

## 配置说明 (Configuration Details)

### 1. Gradle 镜像配置
- 使用阿里云 Maven 镜像：`https://maven.aliyun.com/repository`
- 使用腾讯云 Gradle 分发镜像：`https://mirrors.cloud.tencent.com/gradle`

### 2. 代理配置 (可选)
如果仍然遇到问题，可以配置代理：
- 在 `gradle.properties` 中已配置代理设置
- 默认代理端口：7890 (适用于 Clash 等代理软件)

## 构建步骤 (Build Steps)

### 方法一：使用脚本 (Recommended)
```bash
# Windows 用户
build_china.bat

# 或者使用 PowerShell
.\build_china.ps1
```

### 方法二：手动构建
```bash
# 清理项目
./gradlew clean

# 构建项目
./gradlew build --refresh-dependencies
```

### 方法三：使用 Flutter 命令
```bash
# 清理并重新获取依赖
flutter clean
flutter pub get

# 构建 Android 应用
flutter build apk
```

## 常见问题解决 (Troubleshooting)

### 1. 下载超时
- 检查网络连接
- 尝试使用代理软件
- 增加超时时间设置

### 2. 依赖冲突
- 清理项目：`./gradlew clean`
- 删除 `.gradle` 缓存目录
- 重新同步项目

### 3. 内存不足
- 增加 JVM 内存：修改 `gradle.properties` 中的 `org.gradle.jvmargs`

## 镜像源说明 (Mirror Sources)
- **阿里云 Maven 镜像**：提供 Maven 中央仓库、Google 仓库等镜像
- **腾讯云 Gradle 镜像**：提供 Gradle 分发包镜像
- **华为云镜像**：备用镜像源

## 注意事项 (Notes)
1. 首次构建可能需要较长时间下载依赖
2. 建议在网络状况良好时进行构建
3. 如果遇到特定依赖下载失败，可以尝试切换镜像源

## 技术支持 (Support)
如果遇到问题，请检查：
1. 网络连接是否正常
2. 代理设置是否正确
3. Gradle 版本是否兼容
4. Android SDK 是否正确安装
