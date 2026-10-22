import Foundation

struct Device: Identifiable {
    let id: String
    let name: String
    let model: String
    let connected: Bool
    let online: Bool
    let displayID: UInt32
    let transport: Int
    init?(_ value: [String: Any]) {
        guard let id = value["id"] as? String, let name = value["name"] as? String else { return nil }
        self.id = id; self.name = name; model = value["model"] as? String ?? ""
        connected = value["connected"] as? Bool ?? false; online = value["displayOnline"] as? Bool ?? false
        displayID = (value["displayID"] as? NSNumber)?.uint32Value ?? 0; transport = value["transport"] as? Int ?? 0
    }
}

struct AppSettings: Codable {
    var schemaVersion = 1
    var pairing: Pairing?
    var autoConnect = true
    var headless = false
    var paused = false
}

struct LegacyService {
    let label: String
    let plist: URL
}

enum AppFiles {
    static let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/PadDock", isDirectory: true)
    static let settings = root.appendingPathComponent("settings.json")
    static let legacyRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/iPad Auto Sidecar", isDirectory: true)

    static func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: settings.path) else { return AppSettings() }
        let loaded = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: settings))
        guard loaded.schemaVersion == 1 else { throw NSError(domain: "PadDock", code: 1, userInfo: [NSLocalizedDescriptionKey: "设置文件版本不兼容；自动连接已暂停。请导出诊断后重置设置。"] ) }
        return loaded
    }
    static func save(_ value: AppSettings) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: settings, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settings.path)
    }
    static func legacyServices() throws -> [LegacyService] {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var services: [LegacyService] = files.compactMap { file in
            guard file.pathExtension == "plist", let data = try? Data(contentsOf: file),
                  let object = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let arguments = object["ProgramArguments"] as? [String], let program = arguments.first,
                  let label = object["Label"] as? String else { return nil }
            let url = URL(fileURLWithPath: program)
            guard url.deletingLastPathComponent().standardizedFileURL == legacyRoot.standardizedFileURL,
                  ["ipad-auto-sidecar", "ipad-headless-support"].contains(url.lastPathComponent) else { return nil }
            return LegacyService(label: label, plist: file)
        }
        let task = Process(); let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl"); task.arguments = ["list"]
        task.standardOutput = pipe; task.standardError = FileHandle.nullDevice
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw NSError(domain: "PadDock", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法检查后台任务；自动连接已停止以避免冲突。"]) }
        for label in LegacyJobParser.labels(output: String(decoding: data, as: UTF8.self)) where !services.contains(where: { $0.label == label }) {
            services.append(LegacyService(label: label, plist: folder.appendingPathComponent(label + ".plist")))
        }
        return services
    }
    static func legacyPairing(devices: [Device]) -> Pairing? {
        guard let data = try? Data(contentsOf: legacyRoot.appendingPathComponent("config.json")),
              let cfg = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let usb = cfg["usbSerial"], !usb.isEmpty, let id = cfg["sidecarIdentifier"],
              let device = devices.first(where: { $0.id == id }) else { return nil }
        return Pairing(name: device.name, usbSerial: usb, sidecarID: id)
    }
}
