# PadDock 0.1.0 内测版

把已配对的 iPad 接上 Mac 后，自动通过 USB 发起系统随航。只需安装 Mac App，iPad 使用系统随航，不需要安装配套 App。

## 当前交付

- Apple Silicon 原生菜单栏 App，中文配对、连接状态和偏好设置。
- 只记住你验证过的 iPad；配对期间必须只连接一台 iPad。
- USB 插拔监听、自动重试、暂停、手动连接与断开。
- 可选无显示器模式，以软件虚拟显示器维持随航。
- 可选登录启动、本地配置清理和不含设备标识的诊断导出。
- 检测已有 iPad Auto Sidecar 任务，接管前只读取状态。接管时备份启动配置，并在失败后尝试恢复旧任务。

## 安装与首次使用

1. 打开 `dist/PadDock-0.1.0-arm64.dmg`，把 PadDock 拖入「应用程序」，从那里打开。
2. 新用户只连接目标 iPad，解锁 iPad 并完成系统的信任提示；Mac 和 iPad 需满足系统随航条件。
3. 在 PadDock 中选择 iPad 并验证配对。USB 连接回调成功且画面持续在线后才保存配对。
4. 需要不接实体显示器时，开启「无显示器模式」。需要登录后自动运行时，开启「登录启动」。首次设置及验证建议保留一台实体显示器作为恢复手段。
5. 已有原型的这台 Mac 会显示「旧版服务正在运行」。只有点击「接管现有配置」并确认后才切换。当前交付没有执行接管，旧服务仍维持现有画面。

本包为本地 ad-hoc 签名内测构建，未完成 Developer ID 签名和 Apple 公证。其他 Mac 可能被 Gatekeeper 拦截；不要把它作为公开下载的正式版，也不要关闭系统安全机制来安装。公开测试应先用自己的开发者证书执行发行流程。

## 使用边界

- 当前编译目标为 Apple Silicon、macOS 14+。实际设备环境只有 M4 Mac mini、iPad A16 和当前系统；并未据此声明所有 macOS 14+ 均兼容。
- 自动运行始于用户登录之后，不能在 FileVault 开机解锁界面把 iPad 当作显示器，也不修改 FileVault 或自动登录。
- 随航和虚拟显示器控制依赖系统私有接口，macOS 升级后可能失效。接口检查失败时停止新连接。
- “无显示器模式”依赖 App 持续运行；退出或崩溃可能让唯一的 iPad 画面消失。断开唯一屏幕前会提示。
- 如果原生连接请求迟迟不回调，工具不会并发发送新请求。此情况仍需要在有备用显示器的条件下恢复，不能承诺无人值守恢复。
- 首次配对、无头重连、休眠唤醒、迁移回滚及开机登录仍需完整实机验收。已有原型的验证结果不能替代新 App 的验收，详见 `docs/TESTING.md`。

## 隐私与清理

不使用云服务、账号、遥测或第三方库。配对标识只保存在当前用户的 `~/Library/Application Support/PadDock/settings.json`，权限为 0600。导出的诊断省略设备名称、序列号、用户路径和屏幕内容。

接回备用显示器后，可在偏好设置中「清理本地配置」，再退出并移除 App。清理不会删除迁移备份。旧版任务备份位于 PadDock 支持目录的 `LegacyBackup`；旧原型程序本身保留。

## 开发与发行

```sh
swift test --disable-sandbox --scratch-path .build/tests
xcrun clang -Wall -Wextra -Werror Tests/Native/DisplaySafetyTests.c -o /tmp/paddock-display-tests
/tmp/paddock-display-tests
bash scripts/build.sh
bash scripts/package.sh
```

Xcode 与 macOS SDK 必需。`build.sh` 生成本地签名 App/zip，`package.sh` 生成拖拽安装 DMG 和 SHA-256 校验文件。`PadDock.app/Contents/MacOS/PadDock --self-check` 只读输出接口和设备数量，不启动连接控制器、不创建显示器。

正式发行需在 Keychain 中配置 Developer ID Application 证书和 notarytool 凭据，设置 `PADDOCK_SIGN_IDENTITY` 与 `PADDOCK_NOTARY_PROFILE` 后执行 `bash scripts/release.sh`。脚本不会储存开发者密码，也未在本次交付中执行。私有 API 的长期兼容性、产品名称、许可证、支持条款及收费功能均需在公开销售前另行确认；当前没有付款、授权服务器或自动更新功能。
