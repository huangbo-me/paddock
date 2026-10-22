import SwiftUI

private let ink = Color(red: 0.09, green: 0.14, blue: 0.18)
private let accent = Color(red: 0.00, green: 0.43, blue: 0.38)
private let paper = Color(red: 0.96, green: 0.965, blue: 0.95)

struct Dashboard: View {
    @ObservedObject var app: Controller
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 184)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text(app.selectedPage == 0 ? "你的轻装桌面" : app.selectedPage == 1 ? "按你的方式连接" : "运行状态与支持")
                            .font(.system(size: 25, weight: .semibold, design: .rounded)).foregroundStyle(ink)
                        Spacer()
                        Text("内测版 0.1").font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 10).padding(.vertical, 6).background(.white, in: Capsule()).foregroundStyle(.secondary)
                    }
                    if let error = app.errorMessage { notice(error, icon: "exclamationmark.triangle.fill", warning: true) }
                    if app.selectedPage == 0 { connectionPage }
                    else if app.selectedPage == 1 { settingsPage }
                    else { supportPage }
                }.padding(30)
            }.background(paper)
        }
        .frame(minWidth: 860, idealWidth: 900, minHeight: 660, idealHeight: 700)
        .preferredColorScheme(.light)
        .onAppear { app.tick(); app.refreshLoginStatus() }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "ipad.landscape").font(.system(size: 23, weight: .medium)).foregroundStyle(accent)
                Text("PadDock").font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(ink)
            }.padding(.top, 29).padding(.bottom, 34)
            nav("连接", icon: "cable.connector", index: 0)
            nav("偏好设置", icon: "slider.horizontal.3", index: 1)
            nav("帮助与诊断", icon: "waveform.path.ecg", index: 2)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) { Circle().fill(accent).frame(width: 6, height: 6); Text("本地运行").font(.system(size: 11, weight: .medium)) }
                Text("设备信息保留在此 Mac。\n不上传画面，不需要账户。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(.bottom, 25)
        }.padding(.horizontal, 18).frame(maxHeight: .infinity).background(Color.white)
    }
    private func nav(_ title: String, icon: String, index: Int) -> some View {
        Button { app.selectedPage = index } label: {
            HStack(spacing: 11) { Image(systemName: icon).frame(width: 20); Text(title); Spacer() }
                .font(.system(size: 13, weight: app.selectedPage == index ? .semibold : .regular))
                .foregroundStyle(app.selectedPage == index ? accent : ink.opacity(0.6))
                .padding(.horizontal, 12).padding(.vertical, 12)
                .background(app.selectedPage == index ? accent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 11))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private var connectionPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(app.legacy.isEmpty ? "桌面随行" : "检测到已有配置", systemImage: "sparkle").font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                    Spacer()
                    Circle().fill(app.pairedDevice?.online == true || !app.legacy.isEmpty ? accent : Color.orange).frame(width: 8, height: 8)
                }
                deviceIllustration
                Text(app.statusTitle).font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundStyle(ink)
                Text(app.statusSubtitle).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                if app.busy { ProgressView().controlSize(.small) }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color.white, in: RoundedRectangle(cornerRadius: 18))

            if !app.legacy.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("接着使用你已经调好的桌面").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                    Text("发现原型版后台任务。PadDock 尚未接管控制，当前画面不会受到影响。接管时会先建立新的支持屏幕，并备份旧版任务。")
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
                    Button("接管现有配置") { app.migrateLegacy() }.buttonStyle(PrimaryStyle()).disabled(app.busy)
                    if !app.installed { Text("请先将 App 拖入「应用程序」，再进行接管。") .font(.system(size: 11)).foregroundStyle(.secondary) }
                }.card()
            } else if app.settings.pairing == nil {
                VStack(alignment: .leading, spacing: 14) {
                    Text("第一次使用，只需三步").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                    step("01", "插入数据线", "只连接一台 iPad，解锁并信任此 Mac。")
                    step("02", "选择你的 iPad", "使用同一 Apple 账户，并确保系统随航可用。")
                    HStack {
                        Picker("iPad", selection: $app.selectedID) {
                            if app.devices.isEmpty { Text("尚未发现设备").tag("") }
                            ForEach(app.devices) { Text($0.name).tag($0.id) }
                        }.labelsHidden().frame(maxWidth: .infinity)
                        Button("验证并绑定") { app.pairSelectedDevice() }.buttonStyle(PrimaryStyle()).disabled(app.busy || app.devices.isEmpty || app.usbSerials.count != 1 || !app.apiAvailable)
                    }
                    step("03", "完成自动连接", "验证稳定的 USB 画面后，才会保存设备配对。")
                    if app.usbSerials.count != 1 { Text(app.usbSerials.isEmpty ? "尚未检测到 USB iPad，请检查数据线。" : "检测到多台 USB iPad，请暂时只保留目标设备。") .font(.system(size: 11)).foregroundStyle(.orange) }
                }.card()
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Label(app.settings.pairing?.name ?? "iPad", systemImage: "ipad").font(.system(size: 15, weight: .semibold)); Spacer(); Text("已绑定").font(.system(size: 11)).foregroundStyle(accent) }
                    HStack(spacing: 12) {
                        Button("立即连接") { app.connectNow() }.buttonStyle(PrimaryStyle()).disabled(app.busy)
                        Button(app.settings.paused ? "恢复自动连接" : "暂停自动连接") { app.togglePause() }.buttonStyle(.bordered).disabled(app.busy)
                        Spacer()
                        Button("断开") { app.disconnect() }.buttonStyle(.borderless).foregroundStyle(.secondary).disabled(app.busy || app.pairedDevice?.connected != true)
                    }
                }.card()
            }
            Text("登录 Mac 后生效。FileVault 开机解锁和恢复模式不在支持范围内。")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
        }
    }
    private var deviceIllustration: some View {
        HStack(alignment: .center, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.88, green: 0.90, blue: 0.90)).frame(width: 90, height: 58)
                Image(systemName: "desktopcomputer").font(.system(size: 24, weight: .light)).foregroundStyle(ink.opacity(0.55))
            }
            HStack(spacing: 6) { ForEach(0..<5) { _ in Circle().fill(accent.opacity(0.35)).frame(width: 4, height: 4) } }.padding(.horizontal, 18)
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(ink).frame(width: 156, height: 110)
                RoundedRectangle(cornerRadius: 7).fill(LinearGradient(colors: [Color(red: 0.71, green: 0.86, blue: 0.72), accent], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 142, height: 96)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }.padding(.vertical, 10).accessibilityLabel("Mac 通过数据线连接 iPad")
    }
    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 0) {
                preference("插线自动连接", "只连接已绑定的 iPad，使用 USB 传输。", icon: "cable.connector", value: Binding(get: { app.settings.autoConnect }, set: app.setAutoConnect))
                Divider().padding(.leading, 54)
                preference("无显示器模式", "通过虚拟屏幕支持只使用 iPad 的桌面。", icon: "display.2", value: Binding(get: { app.settings.headless }, set: app.setHeadless))
            }.card().disabled(!app.legacy.isEmpty || app.busy)
            VStack(alignment: .leading, spacing: 12) {
                preference("登录时启动", "进入 Mac 桌面后，自动在菜单栏运行。", icon: "power", value: Binding(get: { app.loginEnabled }, set: app.setLogin))
                if app.needsLoginApproval { Button("在系统设置中允许") { app.openLoginSettings() }.buttonStyle(.bordered) }
                if !app.installed { Text("从「应用程序」文件夹运行后才可启用。") .font(.system(size: 11)).foregroundStyle(.secondary) }
            }.card()
            notice("无显示器模式会在系统显示器列表中增加「PadDock Display」，并镜像 iPad。关闭或退出前，请确认还有其他可用显示器。", icon: "info.circle", warning: false)
            VStack(alignment: .leading, spacing: 12) {
                Text("重置与移除").font(.system(size: 15, weight: .semibold))
                Text("清理配对、偏好设置和登录启动。完成后退出，将 App 移到废纸篓即可。") .font(.system(size: 12)).foregroundStyle(.secondary)
                Button("清理本机配置…") { app.clearConfiguration() }.buttonStyle(.bordered).disabled(app.busy || !app.legacy.isEmpty)
            }.card()
        }
    }
    private var supportPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 14) {
                infoRow("随航接口", value: app.apiAvailable ? "可用" : "不可用")
                infoRow("USB iPad", value: "\(app.usbSerials.count) 台")
                infoRow("无显示器支持", value: app.anchorOnline ? "PadDock 支持屏幕在线" : "未由 PadDock 创建")
                infoRow("后台控制", value: app.legacy.isEmpty ? "PadDock" : "旧版原型")
                infoRow("数据处理", value: "仅保存在本机")
            }.card()
            HStack {
                Button("导出脱敏诊断…") { app.exportDiagnostics() }.buttonStyle(PrimaryStyle())
                Button("打开显示器设置") { app.openDisplaySettings() }.buttonStyle(.bordered)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("当前内测范围").font(.system(size: 15, weight: .semibold))
                Text("Apple Silicon Mac · macOS 14 或更新版本\n实际验证：M4 Mac mini + iPad（A16）\n其他机型和系统版本需进一步测试。") .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(6)
                Divider()
                Text("此版本使用 macOS 未公开的随航和虚拟显示器接口。系统升级可能影响功能。暂未完成 Developer ID 签名与苹果公证，不作为公开商业发行版。") .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5)
            }.card()
        }
    }
    private func preference(_ title: String, _ detail: String, icon: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 14, weight: .medium)); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary) }
            Spacer(); Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).tint(accent)
        }.padding(.vertical, 12)
    }
    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(accent).padding(7).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 12, weight: .semibold)); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary) }
        }
    }
    private func infoRow(_ title: String, value: String) -> some View { HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).foregroundStyle(ink) }.font(.system(size: 12)) }
    private func notice(_ text: String, icon: String, warning: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) { Image(systemName: icon); Text(text).fixedSize(horizontal: false, vertical: true).lineSpacing(4); Spacer(minLength: 0) }
            .font(.system(size: 12)).foregroundStyle(warning ? Color(red: 0.53, green: 0.29, blue: 0.10) : ink.opacity(0.7))
            .padding(16).background(warning ? Color.orange.opacity(0.1) : accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
private extension View {
    func card() -> some View { padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.white, in: RoundedRectangle(cornerRadius: 15)) }
}
struct PrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10).background(accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}
