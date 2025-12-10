import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var selectedTab = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶栏
                GlassHeader(selectedTab: $selectedTab)
                    .environmentObject(engine)

                // 拖放区域
                GlassDropZone(isDragging: $isDragging)
                    .environmentObject(engine)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // 内容区域
                Group {
                    switch selectedTab {
                    case 0: TaskListView()
                    case 1: PasswordListView()
                    case 2: LogListView()
                    default: TaskListView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(engine)

                // 底部控制栏
                GlassControlBar()
                    .environmentObject(engine)
            }
        }
    }
}

// MARK: - 顶栏
struct GlassHeader: View {
    @EnvironmentObject var engine: UnzipEngine
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 20) {
            // 左侧统计
            HStack(spacing: 12) {
                MiniStat(value: engine.totalSuccess, icon: "checkmark.circle.fill", color: .green)
                MiniStat(value: engine.totalFailed, icon: "xmark.circle.fill", color: .red)
            }

            Spacer()

            // 中间 Tab 切换
            HStack(spacing: 2) {
                GlassTab(title: "任务", icon: "list.bullet", isSelected: selectedTab == 0) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 0 }
                }
                GlassTab(title: "密码", icon: "key.fill", isSelected: selectedTab == 1) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                }
                GlassTab(title: "日志", icon: "doc.text", isSelected: selectedTab == 2) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 2 }
                }
            }
            .padding(3)
            .glassEffect(.regular.interactive())

            Spacer()

            // 右侧密码统计
            HStack(spacing: 8) {
                if !engine.cachePasswords.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                        Text("\(engine.cachePasswords.count)")
                    }
                    .font(.caption2)
                }
                HStack(spacing: 3) {
                    Image(systemName: "key")
                        .foregroundStyle(.secondary)
                    Text("\(engine.passwords.count)")
                }
                .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassEffect()
    }
}

struct MiniStat: View {
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(value > 0 ? .primary : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(color.opacity(0.15)))
    }
}

struct GlassTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.background.opacity(0.8))
                        .glassEffect(.regular.interactive())
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 拖放区域
struct GlassDropZone: View {
    @EnvironmentObject var engine: UnzipEngine
    @Binding var isDragging: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(.regular.tint(isDragging ? .blue.opacity(0.1) : .clear))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isDragging ? Color.blue : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: isDragging ? 2 : 1.5, dash: isDragging ? [] : [6, 4])
                        )
                }

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(isDragging ? 0.15 : 0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: isDragging ? "arrow.down.circle.fill" : "arrow.down.doc")
                        .font(.system(size: 22))
                        .foregroundStyle(isDragging ? .blue : .secondary)
                }
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)

                Text("拖放压缩文件到这里")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDragging ? .primary : .secondary)

                Text("支持 zip · rar · 7z · tar.gz")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 100)
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers)
            return true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    if url.hasDirectoryPath {
                        if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                            engine.addFiles(contents)
                        }
                    } else {
                        engine.addFiles([url])
                    }
                }
            }
        }
    }
}

// MARK: - 任务列表
struct TaskListView: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var viewMode: ViewMode = .list

    enum ViewMode: String, CaseIterable {
        case list, tree
    }

    var body: some View {
        VStack(spacing: 0) {
            // 统计栏
            StatsBar(viewMode: $viewMode)
                .environmentObject(engine)

            // 内容
            if engine.tasks.isEmpty {
                emptyState
            } else if viewMode == .list {
                listContent
            } else {
                treeContent
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("暂无任务")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(engine.tasks) { task in
                    TaskCard(task: task)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    var treeContent: some View {
        TreeView()
            .environmentObject(engine)
    }
}

// MARK: - 统计栏
struct StatsBar: View {
    @EnvironmentObject var engine: UnzipEngine
    @Binding var viewMode: TaskListView.ViewMode

    var body: some View {
        HStack(spacing: 0) {
            // 计数
            HStack(spacing: 20) {
                StatItem(label: "待处理", value: engine.pendingCount, color: .secondary)
                StatItem(label: "处理中", value: engine.processingCount, color: .blue)
                StatItem(label: "完成", value: engine.completedCount, color: .green)
                StatItem(label: "失败", value: engine.failedCount, color: .red)
            }

            Spacer()

            // 时间预测
            if engine.isProcessing, let remaining = engine.estimatedRemainingTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(remaining)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(.regular.tint(.orange.opacity(0.1)))
            }

            // 视图切换
            HStack(spacing: 4) {
                ViewModeButton(icon: "list.bullet", isSelected: viewMode == .list) {
                    viewMode = .list
                }
                ViewModeButton(icon: "list.bullet.indent", isSelected: viewMode == .tree) {
                    viewMode = .tree
                }
            }
            .padding(3)
            .glassEffect(.regular.interactive())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

struct StatItem: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(value > 0 ? color : .secondary.opacity(0.4))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

struct ViewModeButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 28, height: 24)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.background.opacity(0.8))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 任务卡片
struct TaskCard: View {
    let task: UnzipTask

    var body: some View {
        HStack(spacing: 14) {
            // 状态图标
            statusIcon
                .frame(width: 28, height: 28)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.fileName)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .lineLimit(1)

                    if task.isSteganography {
                        TagBadge(text: "隐写", color: .purple)
                    }
                    if task.isSelfExtract {
                        TagBadge(text: "自解压", color: .orange)
                    }
                }

                HStack(spacing: 8) {
                    Text(task.status.rawValue)
                        .font(.system(size: 11))
                        .foregroundStyle(statusColor)

                    if let password = task.usedPassword {
                        HStack(spacing: 3) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 9))
                            Text(password)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    }

                    if task.passwordTryCount > 0 && task.status == .tryingPasswords {
                        Text("#\(task.passwordTryCount)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    if let duration = task.duration {
                        Text(duration)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    if let error = task.error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 进度
            if task.status == .tryingPasswords {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .tint(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive())
    }

    @ViewBuilder
    var statusIcon: some View {
        switch task.status {
        case .pending:
            Circle()
                .fill(.secondary.opacity(0.2))
                .overlay {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
        case .extracting, .tryingPasswords:
            ProgressView()
                .scaleEffect(0.6)
        case .success:
            Circle()
                .fill(.green.opacity(0.15))
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                }
        case .failed:
            Circle()
                .fill(.red.opacity(0.15))
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red)
                }
        case .cancelled:
            Circle()
                .fill(.orange.opacity(0.15))
                .overlay {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                }
        }
    }

    var statusColor: Color {
        switch task.status {
        case .pending: return .secondary
        case .extracting, .tryingPasswords: return .blue
        case .success: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

struct TagBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

// MARK: - 树状视图
struct TreeView: View {
    @EnvironmentObject var engine: UnzipEngine

    var groupedTasks: [String: [UnzipTask]] {
        Dictionary(grouping: engine.tasks) { task in
            let dir = (task.filePath as NSString).deletingLastPathComponent
            return dir.isEmpty ? "根目录" : (dir as NSString).lastPathComponent
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedTasks.keys.sorted(), id: \.self) { folder in
                    FolderSection(folderName: folder, tasks: groupedTasks[folder] ?? [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

struct FolderSection: View {
    let folderName: String
    let tasks: [UnzipTask]
    @State private var isExpanded = true

    var successCount: Int { tasks.filter { $0.status == .success }.count }
    var failedCount: Int { tasks.filter { $0.status == .failed }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)

                    Text(folderName)
                        .font(.system(size: 13, weight: .medium))

                    Text("\(tasks.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if successCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9))
                            Text("\(successCount)")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    }

                    if failedCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                            Text("\(failedCount)")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(tasks) { task in
                        TreeFileItem(task: task)
                    }
                }
                .padding(.leading, 28)
            }
        }
    }
}

struct TreeFileItem: View {
    let task: UnzipTask

    var body: some View {
        HStack(spacing: 10) {
            // 连接线
            Rectangle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 1)

            // 状态点
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(task.fileName)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)

            Spacer()

            if let pw = task.usedPassword {
                Text(pw)
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    var statusColor: Color {
        switch task.status {
        case .pending: return .secondary.opacity(0.4)
        case .extracting, .tryingPasswords: return .blue
        case .success: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}


// MARK: - 密码列表
struct PasswordListView: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var newPassword = ""
    @State private var isOneTime = false

    var body: some View {
        VStack(spacing: 0) {
            // 添加密码
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("输入新密码...", text: $newPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit { addPassword() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive())

                Toggle("单次", isOn: $isOneTime)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                Button(action: addPassword) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(newPassword.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .disabled(newPassword.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            ScrollView {
                LazyVStack(spacing: 16) {
                    // 缓存密码
                    if !engine.cachePasswords.isEmpty {
                        PasswordGroup(
                            title: "缓存密码",
                            subtitle: "最近成功",
                            icon: "bolt.fill",
                            color: .yellow
                        ) {
                            ForEach(engine.cachePasswords, id: \.self) { pw in
                                PasswordItem(password: pw, badge: "⚡", badgeColor: .yellow)
                            }
                        }
                    }

                    // 单次密码
                    if !engine.oneTimePasswords.isEmpty {
                        PasswordGroup(
                            title: "单次密码",
                            subtitle: "用后即焚",
                            icon: "flame.fill",
                            color: .orange
                        ) {
                            ForEach(engine.oneTimePasswords) { entry in
                                PasswordItem(
                                    password: entry.password,
                                    badge: entry.markedForDeletion ? "待删" : "🔥",
                                    badgeColor: .orange
                                )
                            }
                        }
                    }

                    // 永久密码
                    PasswordGroup(
                        title: "永久密码",
                        subtitle: "\(engine.passwords.count)个",
                        icon: "key.fill",
                        color: .blue
                    ) {
                        ForEach(engine.passwords) { entry in
                            PasswordItem(
                                password: entry.password,
                                badge: entry.successCount > 0 ? "\(entry.successCount)次" : nil,
                                badgeColor: .green
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func addPassword() {
        guard !newPassword.isEmpty else { return }
        engine.addPassword(newPassword, isOneTime: isOneTime)
        newPassword = ""
    }
}

struct PasswordGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                content
            }
            .padding(12)
            .glassEffect(.regular.tint(color.opacity(0.05)))
        }
    }
}

struct PasswordItem: View {
    let password: String
    let badge: String?
    let badgeColor: Color

    var body: some View {
        HStack {
            Text(password)
                .font(.system(size: 13, design: .monospaced))
            Spacer()
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 11))
                    .foregroundStyle(badgeColor)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 日志列表
struct LogListView: View {
    @EnvironmentObject var engine: UnzipEngine

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("日志")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("清空") {
                    engine.clearLogs()
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if engine.logs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("暂无日志")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(engine.logs) { log in
                            LogItem(log: log)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

struct LogItem: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(logColor)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            Text(log.message)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(2)

            Spacer()

            Text(formatTime(log.timestamp))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(logColor.opacity(0.08)))
    }

    var logColor: Color {
        switch log.level {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - 底部控制栏
struct GlassControlBar: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var showSettings = false
    @State private var showUpdateLog = false

    var body: some View {
        HStack(spacing: 14) {
            // 输出目录
            Button(action: selectOutputDir) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    Text(shortenPath(engine.outputDirectory))
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)

            Spacer()

            // 更新日志
            Button { showUpdateLog.toggle() } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showUpdateLog) {
                UpdateLogView()
            }

            // 设置
            Button { showSettings.toggle() } label: {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(engine)
            }

            // 主按钮
            if engine.isProcessing {
                Button { engine.stopProcessing() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11))
                        Text("停止")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.red.gradient))
                    .glassEffect(.regular.tint(.red.opacity(0.2)))
                }
                .buttonStyle(.plain)
            } else {
                Button { engine.startProcessing() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("开始解压")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(
                            engine.pendingCount > 0 ? Color.blue.gradient : Color.gray.gradient
                        )
                    )
                    .glassEffect(.regular.tint(.blue.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .disabled(engine.pendingCount == 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect()
    }

    private func selectOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            engine.outputDirectory = url.path
        }
    }

    private func shortenPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @EnvironmentObject var engine: UnzipEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("设置")
                    .font(.system(size: 15, weight: .bold))

                SettingGroup(title: "性能", icon: "cpu", color: .blue) {
                    HStack {
                        Text("并发数")
                        Spacer()
                        Stepper("\(engine.maxConcurrent)", value: $engine.maxConcurrent, in: 1...8)
                            .labelsHidden()
                    }
                    Toggle("动态解压", isOn: $engine.dynamicExtract)
                }

                SettingGroup(title: "检测", icon: "magnifyingglass", color: .purple) {
                    Toggle("智能排序", isOn: $engine.smartOrder)
                    Toggle("隐写包检测", isOn: $engine.detectSteganography)
                    Toggle("强制隐写检测", isOn: $engine.forceStegoDetect)
                    Toggle("强制自解压检测", isOn: $engine.forceSelfExtractDetect)
                    Toggle("修复乱码文件名", isOn: $engine.fixEncoding)
                }

                SettingGroup(title: "递归", icon: "arrow.triangle.2.circlepath", color: .orange) {
                    Toggle("递归解压嵌套包", isOn: $engine.recursiveExtract)
                    if engine.recursiveExtract {
                        HStack {
                            Text("最大层数")
                            Spacer()
                            Stepper("\(engine.maxRecursiveDepth)", value: $engine.maxRecursiveDepth, in: 1...20)
                                .labelsHidden()
                        }
                    }
                    Toggle("使用临时目录", isOn: $engine.useTempDirectory)
                }

                SettingGroup(title: "清理", icon: "trash", color: .red) {
                    Toggle("成功后移到回收站", isOn: $engine.autoCleanup)
                    Button("清理单次密码") { engine.cleanupOneTimePasswords() }
                    Button("清空任务列表") { engine.clearTasks() }
                        .disabled(engine.isProcessing)
                }

                SettingGroup(title: "密码", icon: "key", color: .cyan) {
                    Button("导入密码...") { importPasswords() }
                    Button("导出密码...") { exportPasswords() }
                }

                SettingGroup(title: "操作", icon: "arrow.clockwise", color: .green) {
                    Button("重试失败任务") { engine.retryFailed() }
                        .disabled(engine.failedCount == 0)
                    Button("保存设置") { engine.saveSettings() }
                }
            }
            .font(.system(size: 12))
        }
        .frame(width: 280)
        .padding()
    }

    private func importPasswords() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            engine.importPasswords(from: url)
        }
    }

    private func exportPasswords() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "passwords.txt"
        if panel.runModal() == .OK, let url = panel.url {
            engine.exportPasswords(to: url)
        }
    }
}

struct SettingGroup<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.06)))
        }
    }
}

// MARK: - 更新日志
struct UpdateLogView: View {
    @Environment(\.dismiss) var dismiss

    let changelog: [(version: String, date: String, changes: [String])] = [
        ("1.0.0", "2025-12-10", [
            "🎉 首个 macOS 版本发布",
            "✨ 4层密码队列: 字符匹配→缓存→单次→永久",
            "✨ 智能密码排序 (按成功次数)",
            "✨ 隐写包检测 (图片/视频内嵌压缩包)",
            "✨ 分卷压缩包处理 (自动跳过非首包)",
            "✨ 递归解压嵌套压缩包",
            "✨ 乱码文件名修复 (SHIFT-JIS/GB2312)",
            "✨ 动态解压模式",
            "✨ 悬浮密码输入窗口",
            "✨ 单次密码 (用后即焚)",
            "✨ 成功后移到回收站",
            "✨ 密码导入/导出 (兼容原版格式)",
            "✨ 命令行参数支持",
            "✨ 文件计数和时间预测",
            "✨ 树状文件选择视图",
            "🎨 原生 macOS 26 液态玻璃 UI"
        ])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("更新日志")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(changelog, id: \.version) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("v\(entry.version)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Text(entry.date)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(entry.changes, id: \.self) { change in
                                    Text(change)
                                        .font(.system(size: 11))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular.tint(.blue.opacity(0.05)))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 340, height: 420)
    }
}
