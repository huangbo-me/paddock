# PadDock 0.2.0 内测版

把已配对的 iPad 接上 Mac 后，自动通过 USB 发起系统随航。只需安装 Mac App，iPad 使用系统随航，不需要安装配套 App。

## 当前交付

- Apple Silicon 原生菜单栏 App，中文配对、连接状态和偏好设置。
- 只记住你验证过的 iPad；配对期间必须只连接一台 iPad。
- USB 插拔监听、自动重试、暂停、手动连接与断开。
- 可选无显示器模式，以软件虚拟显示器维持随航。
- 可选登录启动、本地配置清理和不含设备标识的诊断导出。
- 14 天完整试用、离线激活、爱发电购买入口。此包尚未配置商品，购买按钮暂时禁用。
- 检测已有 iPad Auto Sidecar 任务，接管前只读取状态。接管时备份启动配置，并在失败后尝试恢复旧任务。

## 安装与首次使用

1. 打开 `dist/PadDock-0.2.0-arm64.dmg`，把 PadDock 拖入「应用程序」，从那里打开。升级前保留备用屏幕：替换、退出 App 可能中断唯一的 iPad 画面。
2. 新用户只连接目标 iPad，解锁 iPad 并完成系统的信任提示；Mac 和 iPad 需满足系统随航条件。
3. 在「购买与激活」开始 14 天试用，或粘贴已有激活码；再选择 iPad 并验证配对。USB 连接回调成功且画面持续在线后才保存配对。
4. 需要不接实体显示器时，开启「无显示器模式」。需要登录后自动运行时，开启「登录启动」。首次设置及验证建议保留一台实体显示器作为恢复手段。
5. 若检测到旧版原型服务，只有点击「接管现有配置」并确认后才切换。已安装 0.1.0 的用户会保留原有配对配置；此开发交付没有替换正在运行的 App。

本包为本地 ad-hoc 签名内测构建，未完成 Developer ID 签名和 Apple 公证。其他 Mac 可能被 Gatekeeper 拦截；不要把它作为公开下载的正式版，也不要关闭系统安全机制来安装。公开测试应先用自己的开发者证书执行发行流程。

## 使用边界

- 当前编译目标为 Apple Silicon、macOS 14+。实际设备环境只有 M4 Mac mini、iPad A16 和当前系统；并未据此声明所有 macOS 14+ 均兼容。
- 自动运行始于用户登录之后，不能在 FileVault 开机解锁界面把 iPad 当作显示器，也不修改 FileVault 或自动登录。
- 随航和虚拟显示器控制依赖系统私有接口，macOS 升级后可能失效。接口检查失败时停止新连接。
- “无显示器模式”依赖 App 持续运行；退出或崩溃可能让唯一的 iPad 画面消失。断开唯一屏幕前会提示。
- 如果原生连接请求迟迟不回调，工具不会并发发送新请求。此情况仍需要在有备用显示器的条件下恢复，不能承诺无人值守恢复。
- 首次配对、无头重连、休眠唤醒、迁移回滚及开机登录仍需完整实机验收。已有原型的验证结果不能替代新 App 的验收，详见 `docs/TESTING.md`。

## 隐私与清理

App 不上传画面、设备标识或遥测，无需注册 PadDock 账号。购买通过浏览器进入爱发电，其账号和订单由平台处理。配对标识只保存在当前用户的 `~/Library/Application Support/PadDock/settings.json`，权限为 0600。导出的诊断省略设备名称、序列号、用户路径和屏幕内容。试用时间及激活码保存在本机钥匙串，不进入诊断。

接回备用显示器后，可在偏好设置中「清理本地配置」，再退出并移除 App。清理不会删除迁移备份或重置试用/授权。旧版任务备份位于 PadDock 支持目录的 `LegacyBackup`。

## 试用与激活

试用从点击开始计时，共 14×24 小时。激活码解锁商业版本线 1（包含当前 0.2.x 内测），无需定期联网验证，不限制机器数量，也不能远程吊销。重装 App、清理偏好不会重置钥匙串中的试用；离线试用并非不可绕过的防盗版机制。

到期或授权异常不会主动断开当前画面。手动恢复始终保留；已配对的无显示器模式在无法确认其他可用屏幕时继续自动恢复。当前只把在线内置屏幕作为明确证据，外接屏、虚拟屏和模拟插头均保守处理，因此 Mac mini 的已配置无显示器恢复可能在到期后继续工作。

若升级后显示「授权记录暂不可用」，点击「重新读取授权」以授权钥匙串访问；不要删除旧记录来重置试用。后台检查不会主动弹出权限窗口。爱发电配置、发码及待完成的真实付款验证见仓库中的 `docs/AFDIAN_SETUP.md`。

## 开发与发行

```sh
swift test --disable-sandbox --scratch-path .build/tests
xcrun clang -Wall -Wextra -Werror Tests/Native/DisplaySafetyTests.c -o /tmp/paddock-display-tests
/tmp/paddock-display-tests
bash scripts/build.sh
bash scripts/package.sh
bash scripts/build-license-tool.sh
python3 scripts/test-license-tool.py
bash scripts/verify-artifacts.sh
```

Xcode 与 macOS SDK 必需。`build.sh` 生成本地签名 App/zip，`package.sh` 生成拖拽安装 DMG 和 SHA-256 校验文件。`PadDock.app/Contents/MacOS/PadDock --self-check` 只读输出接口和设备数量，不启动连接控制器、不创建显示器。

正式发行需在 Keychain 中配置 Developer ID Application 证书和 notarytool 凭据，设置 `PADDOCK_SIGN_IDENTITY` 与 `PADDOCK_NOTARY_PROFILE` 后执行 `bash scripts/release.sh`。脚本不会储存开发者密码，也未在本次交付中执行。私有 API 的长期兼容性、产品名称、许可证及支持条款需在公开销售前确认。当前已提供离线授权；没有授权服务器、支付回调或自动更新功能。
