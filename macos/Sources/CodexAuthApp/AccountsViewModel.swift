import Foundation
import Combine

class AccountsViewModel: ObservableObject {
    @Published var accounts: [AccountInfo] = []
    @Published var autoSwitchEnabled = false
    @Published var apiUsageEnabled = true
    @Published var isLoading = false
    @Published var error: String?

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var monitorFd: Int32 = -1

    private static let codexHome: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }()

    private static let registryURL: URL = {
        codexHome.appendingPathComponent("accounts/registry.json")
    }()

    private static var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private static var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    init() {
        load()
        startWatching()
    }

    deinit {
        fileMonitor?.cancel()
        if monitorFd >= 0 { close(monitorFd) }
    }

    // MARK: - Load

    func load() {
        guard let data = try? Data(contentsOf: Self.registryURL),
              let reg = try? Self.decoder.decode(RegistryData.self, from: data) else {
            accounts = []
            error = "未找到 registry.json"
            return
        }
        error = nil

        // 按活跃状态排序：活跃账号排在最前
        let activeKey = reg.activeAccountKey
        accounts = reg.accounts
            .map { makeAccountInfo($0, activeKey: activeKey) }
            .sorted { a, b in
                if a.isActive != b.isActive { return a.isActive }
                return a.email < b.email
            }
        autoSwitchEnabled = reg.autoSwitch.enabled
        apiUsageEnabled = reg.api.usage
    }

    // MARK: - Switch Account

    func switchTo(_ accountKey: String) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.performSwitch(accountKey)
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err = result { self?.error = err }
                self?.load()
            }
        }
    }

    private func performSwitch(_ accountKey: String) -> String? {
        let home = Self.codexHome
        let fileKey = accountFileKey(accountKey)
        let src = home.appendingPathComponent("accounts/\(fileKey).auth.json")
        let dst = home.appendingPathComponent("auth.json")

        // 复制账号的 auth.json 到活跃位置
        do {
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.copyItem(at: src, to: dst)
        } catch {
            return "切换失败: \(error.localizedDescription)"
        }

        // 更新 registry
        return updateRegistry { reg in
            reg.activeAccountKey = accountKey
            reg.activeAccountActivatedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        }
    }

    // MARK: - Config

    func setAutoSwitch(_ enabled: Bool) {
        let err = updateRegistry { reg in reg.autoSwitch.enabled = enabled }
        if let err = err { error = err }
        load()
    }

    func setApiUsage(_ enabled: Bool) {
        let err = updateRegistry { reg in
            reg.api.usage = enabled
            reg.api.account = enabled
        }
        if let err = err { error = err }
        load()
    }

    // MARK: - Registry I/O

    private func updateRegistry(_ mutate: (inout RegistryData) -> Void) -> String? {
        guard let data = try? Data(contentsOf: Self.registryURL),
              var reg = try? Self.decoder.decode(RegistryData.self, from: data) else {
            return "无法读取 registry"
        }
        mutate(&reg)
        guard let output = try? Self.encoder.encode(reg) else {
            return "序列化失败"
        }
        do {
            try output.write(to: Self.registryURL)
        } catch {
            return "写入失败: \(error.localizedDescription)"
        }
        return nil
    }

    // MARK: - File Watching

    private func startWatching() {
        let path = Self.registryURL.path
        monitorFd = open(path, O_EVTONLY)
        guard monitorFd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: monitorFd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.load()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.monitorFd, fd >= 0 { Darwin.close(fd) }
            self?.monitorFd = -1
        }
        source.resume()
        fileMonitor = source
    }
}
