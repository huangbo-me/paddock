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
                        Text(app.selectedPage == 0 ? "连接" : app.selectedPage == 1 ? "设置" : "帮助")
                            .font(.system(size: 25, weight: .semibold, design: .rounded)).foregroundStyle(ink)
                        Spacer()
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
            nav("设置", icon: "slider.horizontal.3", index: 1)
            nav("帮助", icon: "questionmark.circle", index: 2)
            Spacer()
            Text("PadDock 0.2.2").font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 25)
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
                    Text(app.legacy.isEmpty ? "我的 iPad" : "发现旧版配置").font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                    Spacer()
                    Circle().fill(app.pairedDevice?.online == true || !app.legacy.isEmpty ? accent : Color.orange).frame(width: 8, height: 8)
                }
                deviceIllustration
                Text(app.statusTitle).font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundStyle(ink)
                Text(app.statusSubtitle).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                if app.busy || app.disconnecting { ProgressView().controlSize(.small) }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color.white, in: RoundedRectangle(cornerRadius: 18))

            if !app.legacy.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("继续使用原有设置").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                    Text("保留已配对的 iPad，切换到新版。")
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
                    Button("使用原有设置") { app.migrateLegacy() }.buttonStyle(PrimaryStyle()).disabled(app.busy)
                    if !app.installed { Text("请先将 App 拖入「应用程序」，再进行接管。") .font(.system(size: 11)).foregroundStyle(.secondary) }
                }.card()
            } else if app.settings.pairing == nil {
                VStack(alignment: .leading, spacing: 14) {
                    Text("连接你的 iPad").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                    Text("用数据线连接并解锁 iPad，按提示信任这台 Mac。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    HStack {
                        Picker("iPad", selection: $app.selectedID) {
                            if app.devices.isEmpty { Text("尚未发现设备").tag("") }
                            ForEach(app.devices) { Text($0.name).tag($0.id) }
                        }.labelsHidden().frame(maxWidth: .infinity)
                        Button("连接此 iPad") { app.pairSelectedDevice() }.buttonStyle(PrimaryStyle()).disabled(app.busy || app.devices.isEmpty || app.usbSerials.count != 1 || !app.apiAvailable)
                    }
                    if app.usbSerials.count != 1 { Text(app.usbSerials.isEmpty ? "尚未检测到 USB iPad，请检查数据线。" : "检测到多台 USB iPad，请暂时只保留目标设备。") .font(.system(size: 11)).foregroundStyle(.orange) }
                }.card()
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Label(app.settings.pairing?.name ?? "iPad", systemImage: "ipad").font(.system(size: 15, weight: .semibold)); Spacer(); Text("已绑定").font(.system(size: 11)).foregroundStyle(accent) }
                    HStack(spacing: 12) {
                        Button(app.isConnected ? "已连接" : "立即连接") { app.connectNow() }.buttonStyle(PrimaryStyle()).disabled(app.busy || app.disconnecting || app.isConnected)
                        Button(app.automaticConnectionTitle) { app.togglePause() }.buttonStyle(.bordered).disabled(app.busy || app.disconnecting)
                        Spacer()
                        Button(app.disconnecting ? "正在断开…" : "断开") { app.disconnect() }.buttonStyle(.borderless).foregroundStyle(.secondary).disabled(app.busy || app.disconnecting || (app.pairedDevice?.connected != true && app.pairedDevice?.online != true))
                    }
                }.card()
            }
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
                preference("插线自动连接", "接上这台 iPad 后自动连接。", icon: "cable.connector", value: Binding(get: { app.settings.autoConnect }, set: app.setAutoConnect))
                Divider().padding(.leading, 54)
                preference("仅用 iPad 显示", "不接其他显示器时开启。", icon: "display.2", value: Binding(get: { app.settings.headless }, set: app.setHeadless))
            }.card().disabled(!app.legacy.isEmpty || app.busy || app.disconnecting)
            VStack(alignment: .leading, spacing: 12) {
                preference("登录时启动", "登录 Mac 后自动运行。", icon: "power", value: Binding(get: { app.loginEnabled }, set: app.setLogin))
                if app.needsLoginApproval { Button("在系统设置中允许") { app.openLoginSettings() }.buttonStyle(.bordered) }
                if !app.installed { Text("从「应用程序」文件夹运行后才可启用。") .font(.system(size: 11)).foregroundStyle(.secondary) }
            }.card()
            VStack(alignment: .leading, spacing: 12) {
                Text("重置").font(.system(size: 15, weight: .semibold))
                Button("重置设置…") { app.clearConfiguration() }.buttonStyle(.bordered).disabled(app.busy || !app.legacy.isEmpty)
            }.card()
        }
    }
    private var supportPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 14) {
                Text("无法连接？").font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                Text("检查数据线，解锁 iPad，并确认两台设备使用同一 Apple 账户。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }.card()
            HStack {
                Button("打开显示器设置") { app.openDisplaySettings() }.buttonStyle(.bordered)
                Button("导出问题报告…") { app.exportDiagnostics() }.buttonStyle(.bordered)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("关于 PadDock").font(.system(size: 15, weight: .semibold))
                Text("0.2.2 · 内测版").font(.system(size: 12)).foregroundStyle(.secondary)
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
    private func notice(_ text: String, icon: String, warning: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) { Image(systemName: icon); Text(text).fixedSize(horizontal: false, vertical: true).lineSpacing(4); Spacer(minLength: 0) }
            .font(.system(size: 12)).foregroundStyle(warning ? Color(red: 0.53, green: 0.29, blue: 0.10) : ink.opacity(0.7))
            .padding(16).background(warning ? Color.orange.opacity(0.1) : accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
private extension View {
    func card() -> some View { padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.white, in: RoundedRectangle(cornerRadius: 15)) }
}
