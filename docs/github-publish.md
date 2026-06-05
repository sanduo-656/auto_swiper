# GitHub Publish Guide

这份文档用于把 Auto Swiper 发布到 GitHub。

## 1. 创建 GitHub 仓库

在 GitHub 新建仓库，例如：

```text
auto_swiper
```

建议设置：

- Visibility: Public
- README: 不勾选，仓库里已经有 README
- License: 不勾选，仓库里已经有 MIT License
- `.gitignore`: 不勾选，仓库里已经有 Flutter/Android `.gitignore`

## 2. 添加 GitHub remote

在本地仓库执行：

```powershell
git remote add github https://github.com/<your-name>/auto_swiper.git
```

如果已经添加过，可以查看：

```powershell
git remote -v
```

## 3. 推送主分支

确认本地分支和提交：

```powershell
git status
git log --oneline -5
```

推送到 GitHub：

```powershell
git push github main
```

如果要把版本标签也同步到 GitHub：

```powershell
git push github --tags
```

## 4. 构建发布 APK

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

通用 APK 输出位置：

```text
build/app/outputs/flutter-apk/app-release.apk
```

如果通用 APK 太大，可以使用 ABI 拆分：

```powershell
flutter build apk --release --split-per-abi
```

拆分 APK 输出位置：

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

## 5. 生成校验文件

```powershell
Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256
```

也可以把结果保存为文本文件：

```powershell
Get-FileHash build/app/outputs/flutter-apk/app-release.apk -Algorithm SHA256 |
  Format-List |
  Out-File build/app/outputs/flutter-apk/app-release.sha256.txt
```

## 6. 创建 GitHub Release

在 GitHub 仓库页面进入 Releases，创建新版本。

建议：

- Tag: `v0.0.2`
- Title: `Auto Swiper v0.0.2`
- Assets: 上传 APK 和 sha256 文本

Release 文案可以参考：

```md
## Auto Swiper v0.0.2

这是 Auto Swiper 的公开版本。

### 功能

- 随机滑动、点击、连点。
- 支持开始后回到上一个 App 或打开指定 App。
- 支持运行小窗、点击标靶和调试日志。
- 优化手机竖屏和 Pad/宽屏控制台布局。

### 安装

1. 下载 APK。
2. 在 Android 设备上安装。
3. 打开应用并开启“随机滑屏”无障碍服务。
4. 回到应用配置参数并开始运行。

### 注意

请只将本工具用于个人自动化、测试、学习和研究场景。不要用于刷量、作弊、绕过第三方平台规则或其他不当用途。
```

## 7. 发布后检查

- GitHub README 能正常展示。
- Release 中能下载 APK。
- 新设备安装 APK 后能打开应用。
- 无障碍服务名称显示为“随机滑屏”。
- 开始、停止、运行小窗和指定 App 入口可用。
