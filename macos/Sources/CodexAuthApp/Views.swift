import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @StateObject var vm = AccountsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if let err = vm.error, vm.accounts.isEmpty {
                emptyView(err)
            } else {
                accountsList
            }

            Divider()
            settingsSection
            Divider()
            footerView
        }
        .frame(width: 380)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
            Text("Codex Auth")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if vm.isLoading {
                ProgressView().controlSize(.small)
            }
            Text("v0.1").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Empty

    private func emptyView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28)).foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text("先在终端运行 codex-auth login")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(vm.accounts) { account in
                    AccountCard(account: account) {
                        if !account.isActive { vm.switchTo(account.accountKey) }
                    }
                }
            }
            .padding(10)
        }
        .frame(maxHeight: 340)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 6) {
            HStack {
                Label("Auto-switch", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { vm.autoSwitchEnabled },
                    set: { vm.setAutoSwitch($0) }
                )).toggleStyle(.switch).controlSize(.small)
            }
            HStack {
                Label("Usage API", systemImage: "network")
                    .font(.system(size: 12))
                Spacer()
                Text(vm.apiUsageEnabled ? "api" : "local")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Toggle("", isOn: Binding(
                    get: { vm.apiUsageEnabled },
                    set: { vm.setApiUsage($0) }
                )).toggleStyle(.switch).controlSize(.small)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footerView: some View {
        Button(action: { NSApp.terminate(nil) }) {
            Text("Quit")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }
}

// MARK: - Account Card

struct AccountCard: View {
    let account: AccountInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                // 邮箱 + 计划标签
                HStack(spacing: 6) {
                    Circle()
                        .fill(account.isActive ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 7, height: 7)
                    Text(account.displayName)
                        .font(.system(size: 12, weight: account.isActive ? .semibold : .regular))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if let plan = account.plan {
                        PlanBadge(plan: plan)
                    }
                }

                // 用量条
                HStack(spacing: 12) {
                    if let pct = account.usage5hRemaining {
                        UsageBar(label: "5h", percent: pct)
                    }
                    if let pct = account.usageWeeklyRemaining {
                        UsageBar(label: "wk", percent: pct)
                    }
                    if account.usage5hRemaining == nil && account.usageWeeklyRemaining == nil {
                        Text("无用量数据").font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(account.isActive
                          ? Color.green.opacity(0.08)
                          : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(account.isActive ? Color.green.opacity(0.25) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Plan Badge

struct PlanBadge: View {
    let plan: String

    var body: some View {
        Text(plan.capitalized)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var color: Color {
        switch plan.lowercased() {
        case "pro": return .purple
        case "plus": return .blue
        case "team": return .orange
        case "enterprise", "business": return .red
        default: return .gray
        }
    }
}

// MARK: - Usage Bar

struct UsageBar: View {
    let label: String
    let percent: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .frame(width: 16, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(percent) / 100)
                }
            }
            .frame(height: 5)
            Text("\(percent)%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(barColor)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var barColor: Color {
        if percent >= 60 { return .green }
        if percent >= 30 { return .orange }
        return .red
    }
}
