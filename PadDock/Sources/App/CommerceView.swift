import SwiftUI

struct CommerceView: View {
    @ObservedObject var store: CommerceStore
    var recoveryProtected: Bool
    private let green = Color(red: 0, green: 0.43, blue: 0.38)
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Label(store.title, systemImage: store.entitled ? "checkmark.seal.fill" : "key.fill")
                    .font(.system(size: 21, weight: .semibold)).foregroundStyle(green)
                Text("一次购买，解锁当前大版本。激活后可离线使用。")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                if store.status == .notStarted {
                    Button("开始 14 天试用") { store.startTrial() }.buttonStyle(PrimaryStyle())
                }
                if store.status == .clockChanged { Text("检测到明显的时钟回拨。请恢复正确日期后重试；有效的付费激活码仍可使用。") .font(.system(size: 12)).foregroundStyle(.secondary) }
                if store.status == .unavailable {
                    Button("重新读取授权") { store.authorizeAndReload() }.buttonStyle(.bordered)
                    Text("此操作可能请求钥匙串访问权限。请确认请求来自 PadDock；允许后会保留原有试用和授权记录。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if recoveryProtected { Text("为避免唯一的 iPad 屏幕无法恢复，当前仍保留无显示器连接恢复。授权异常不会主动断开画面。") .font(.system(size: 12)).foregroundStyle(.secondary) }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 12) {
                Text("通过爱发电购买").font(.system(size: 16, weight: .semibold))
                Text(store.purchaseURL == nil ? "商品尚未上线，当前安装包暂不接受付款。你仍可试用或输入已有激活码。" : "在爱发电完成付款后，查看自动回复中的激活码，完整复制到下方。价格以商品页面为准。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
                Button(store.purchaseURL == nil ? "尚未开放购买" : "前往爱发电购买") { store.openPurchase() }
                    .buttonStyle(PrimaryStyle()).disabled(store.purchaseURL == nil)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 12) {
                Text("输入激活码").font(.system(size: 16, weight: .semibold))
                TextField("粘贴以 PD1. 开头的完整激活码", text: $store.activationInput, axis: .vertical)
                    .lineLimit(2...4).textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced))
                    .onChange(of: store.activationInput) { _, value in
                        if value.utf8.count > 8192 { store.activationInput = String(value.prefix(8192)) }
                    }
                HStack {
                    Button("激活授权") { store.activate() }.buttonStyle(PrimaryStyle())
                        .disabled(store.activationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.status == .unavailable)
                    Text("无需输入爱发电密码或 API Token").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if let message = store.message { Text(message).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled) }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16))
            Text("离线激活版不做机器绑定，也不支持远程吊销。请妥善保管激活码，不要公开分享。试用记录保留在本机钥匙串，清理偏好设置不会重置试用。")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
        }
    }
}
struct CommerceBanner: View {
    @ObservedObject var store: CommerceStore
    let open: () -> Void
    var body: some View {
        HStack {
            Label(store.title, systemImage: "key").font(.system(size: 12))
            Spacer()
            Button(store.entitled ? "授权详情" : "试用与激活", action: open).buttonStyle(.bordered)
        }.padding(14).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
    }
}
