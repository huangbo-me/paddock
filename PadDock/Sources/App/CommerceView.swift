import SwiftUI

struct CommerceView: View {
    @ObservedObject var store: CommerceStore
    private let green = Color(red: 0, green: 0.43, blue: 0.38)
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Label(store.title, systemImage: store.entitled ? "checkmark.seal.fill" : "key.fill")
                    .font(.system(size: 21, weight: .semibold)).foregroundStyle(green)
                Text("购买后可永久使用此版本。")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                if store.status == .notStarted {
                    Button("开始 14 天试用") { store.startTrial() }.buttonStyle(PrimaryStyle())
                }
                if store.status == .clockChanged { Text("请将 Mac 的日期和时间设为自动后重试。") .font(.system(size: 12)).foregroundStyle(.secondary) }
                if store.status == .unavailable {
                    Button("重试") { store.authorizeAndReload() }.buttonStyle(.bordered)
                }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 12) {
                Text("购买").font(.system(size: 16, weight: .semibold))
                Text(store.purchaseURL == nil ? "暂未开放购买。" : "购买后，将收到的激活码粘贴到下方。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
                Button(store.purchaseURL == nil ? "即将开放" : "前往爱发电") { store.openPurchase() }
                    .buttonStyle(PrimaryStyle()).disabled(store.purchaseURL == nil)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 12) {
                Text("输入激活码").font(.system(size: 16, weight: .semibold))
                TextField("粘贴激活码", text: $store.activationInput, axis: .vertical)
                    .lineLimit(2...4).textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced))
                    .onChange(of: store.activationInput) { _, value in
                        if value.utf8.count > 8192 { store.activationInput = String(value.prefix(8192)) }
                    }
                HStack {
                    Button("激活") { store.activate() }.buttonStyle(PrimaryStyle())
                        .disabled(store.activationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.status == .unavailable)
                }
                if let message = store.message { Text(message).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled) }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16))
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
            Button(store.entitled ? "查看" : "试用与激活", action: open).buttonStyle(.bordered)
        }.padding(14).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
    }
}
