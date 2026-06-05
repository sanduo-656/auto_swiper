# Contributing

感谢你愿意改进 Auto Swiper。

## 提交 Issue

请尽量包含以下信息：

- Android 版本和设备型号。
- App 版本。
- 问题现象。
- 复现步骤。
- 预期结果和实际结果。
- 如果方便，请附上截图或调试日志。

## 提交 Pull Request

建议流程：

1. Fork 仓库。
2. 从 `main` 创建分支。
3. 修改代码或文档。
4. 运行基础验证。
5. 提交 Pull Request，并说明修改内容和验证方式。

基础验证：

```powershell
flutter analyze
flutter test
```

如果修改了 Android Kotlin、Manifest、资源或无障碍服务配置，请补充：

```powershell
flutter build apk --debug
```

## 使用边界

本项目依赖 Android `AccessibilityService`。请不要提交用于刷量、作弊、绕过平台规则或侵害他人权益的功能。
