import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var selectedTab = 0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            // 液态玻璃顶栏
            LiquidGlassHeader(selectedTab: $selectedTab)
                .environmentObject(engine)

            // 拖放区域
            DropZoneView(isDragging: $isDragging)
                .environmentObject(engine)
                .padding(.horizontal, 16)
                .padding(.top, 12)

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

            // 底部控制栏
            LiquidGlassControlBar()
                .environmentObject(engine)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 液态玻璃顶栏
struct LiquidGlassHeader: View {
    @EnvironmentObject var engine: UnzipEngine
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 16) {
            // 统计徽章
            HStack(spacing: 8) {
                StatBadge(icon: "checkmark.circle.fill", count: engine.totalSuccess, color: .green)
                StatBadge(icon: "xmark.circle.fill", count: engine.totalFailed, color: .red)
            }

            Spacer()

            // Tab 切换 - 原生液态玻璃
            HStack(spacing: 0) {
                TabButton(title: "任务", icon: "list.bullet", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabButton(title: "密码", icon: "key.fill", isSelected: selectedTab == 1) { selectedTab = 1 }
                TabButton(title: "日志", icon: "doc.text", isSelected: selectedTab == 2) { selectedTab = 2 }
            }
            .padding(4)
            .glassEffect(.regular.interactive())

            Spacer()

            // 密码统计
            HStack(spacing: 6) {
                if !engine.cachePasswords.isEmpty {
                    Label("\(engine.cachePasswords.count)", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                Label("\(engine.passwords.count + engine.oneTimePasswords.count)", systemImage: "key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect()
    }
}

struct StatBadge: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text("\(count)")
                .fontWeight(.medium)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(color.opacity(0.3)))
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.background)
                        .glassEffect(.regular.interactive())
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 拖放区域
struct DropZoneView: View {
    @EnvironmentObject var engine: UnzipEngine
    @Binding var isDragging: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: isDragging ? [] : [8])
                )
                .glassEffect(.regular.tint(isDragging ? .blue.opacity(0.1) : .clear))

            VStack(spacing: 6) {
                Image(systemName: isDragging ? "arrow.down.circle.fill" : "arrow.down.doc.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isDragging ? .accentColor : .secondary)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isDragging)

                Text("拖放压缩文件")
                    .font(.subheadline)
                    .foregroundColor(isDragging ? .primary : .secondary)
                Text("zip · rar · 7z · tar.gz")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(height: 85)
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
    @State private var viewMode: TaskViewMode = .list

    enum TaskViewMode: String, CaseIterable {
        case list = "列表"
        case tree = "树状"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 统计栏
            TaskStatsBar(viewMode: $viewMode)
                .environmentObject(engine)

            // 内容
            if viewMode == .list {
                taskListContent
            } else {
                TaskTreeView()
                    .environmentObject(engine)
            }
        }
        .overlay {
            if engine.tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无任务")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    var taskListContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(engine.tasks) { task in
                    TaskRowView(task: task)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 任务统计栏 (文件计数+时间预测)
struct TaskStatsBar: View {
    @EnvironmentObject var engine: UnzipEngine
    @Binding var viewMode: TaskListView.TaskViewMode

    var body: some View {
        HStack(spacing: 12) {
            // 文件计数
            HStack(spacing: 16) {
                CountBadge(label: "待处理", count: engine.pendingCount, color: .secondary)
                CountBadge(label: "处理中", count: engine.processingCount, color: .blue)
                CountBadge(label: "完成", count: engine.completedCount, color: .green)
                CountBadge(label: "失败", count: engine.failedCount, color: .red)
            }

            Spacer()

            // 时间预测
            if engine.isProcessing, let remaining = engine.estimatedRemainingTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(remaining)
                }
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .glassEffect(.regular.tint(.orange.opacity(0.1)))
            }

            // 视图切换
            Picker("", selection: $viewMode) {
                ForEach(TaskListView.TaskViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode == .list ? "list.bullet" : "list.bullet.indent")
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 70)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(.clear))
    }
}

struct CountBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundColor(count > 0 ? color : .secondary.opacity(0.5))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 树状文件视图
struct TaskTreeView: View {
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
                    TreeFolderView(
                        folderName: folder,
                        tasks: groupedTasks[folder] ?? []
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct TreeFolderView: View {
    let folderName: String
    let tasks: [UnzipTask]
    @State private var isExpanded = true

    var successCount: Int { tasks.filter { $0.status == .success }.count }
    var failedCount: Int { tasks.filter { $0.status == .failed }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 文件夹头
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundColor(.blue)
                    Text(folderName)
                        .fontWeight(.medium)
                    Text("\(tasks.count)个文件")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if successCount > 0 {
                        Text("✓\(successCount)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if failedCount > 0 {
                        Text("✗\(failedCount)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive())

            // 文件列表
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(tasks) { task in
                        TreeFileRow(task: task)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }
}

struct TreeFileRow: View {
    let task: UnzipTask

    var body: some View {
        HStack(spacing: 8) {
            // 连接线
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 20)

            // 状态图标
            statusIcon
                .frame(width: 16)

            // 文件名
            Text(task.fileName)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            Spacer()

            // 密码/错误
            if let pw = task.usedPassword {
                Text(pw)
                    .font(.caption2)
                    .foregroundColor(.green)
            } else if let err = task.error {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    var statusIcon: some View {
        Group {
            switch task.status {
            case .pending:
                Image(systemName: "circle").foregroundColor(.secondary)
            case .extracting, .tryingPasswords:
                ProgressView().scaleEffect(0.5)
            case .success:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            case .cancelled:
                Image(systemName: "minus.circle").foregroundColor(.orange)
            }
        }
        .font(.caption)
    }
}

struct TaskRowView: View {
    let task: UnzipTask

    var body: some View {
        HStack(spacing: 12) {
            statusIcon.frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.fileName)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    
                    // 标记
                    if task.isSteganography {
                        Text("隐写")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.purple.opacity(0.2)))
                            .foregroundColor(.purple)
                    }
                    if task.isSelfExtract {
                        Text("自解压")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.orange.opacity(0.2)))
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 6) {
                    Text(task.status.rawValue)
                        .font(.caption)
                        .foregroundColor(statusColor)

                    if let password = task.usedPassword {
                        HStack(spacing: 2) {
                            Image(systemName: "key.fill")
                            Text(password)
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                    }
                    
                    // 密码测试计数 (原作者功能)
                    if task.passwordTryCount > 0 && task.status == .tryingPasswords {
                        Text("尝试#\(task.passwordTryCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // 耗时
                    if let duration = task.duration {
                        Text(duration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let error = task.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            if task.status == .tryingPasswords {
                ProgressView(value: task.progress)
                    .frame(width: 50)
                    .tint(.blue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive())
    }

    var statusIcon: some View {
        Group {
            switch task.status {
            case .pending:
                Image(systemName: "clock").foregroundColor(.secondary)
            case .extracting, .tryingPasswords:
                ProgressView().scaleEffect(0.7)
            case .success:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            case .cancelled:
                Image(systemName: "minus.circle.fill").foregroundColor(.orange)
            }
        }
        .font(.system(size: 18))
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


// MARK: - 密码列表
struct PasswordListView: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var newPassword = ""
    @State private var isOneTime = false

    var body: some View {
        VStack(spacing: 0) {
            // 添加密码区
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "plus")
                        .foregroundColor(.secondary)
                    TextField("添加新密码...", text: $newPassword)
                        .textFieldStyle(.plain)
                        .onSubmit { addPassword() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive())

                Toggle("单次", isOn: $isOneTime)
                    .toggleStyle(.checkbox)
                    .help("用后即焚")

                Button(action: addPassword) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(newPassword.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .disabled(newPassword.isEmpty)
            }
            .padding()

            ScrollView {
                LazyVStack(spacing: 12) {
                    // 缓存密码
                    if !engine.cachePasswords.isEmpty {
                        PasswordSection(title: "缓存密码", subtitle: "最近成功", icon: "bolt.fill", color: .yellow) {
                            ForEach(engine.cachePasswords, id: \.self) { pw in
                                PasswordRow(password: pw, badge: "⚡", badgeColor: .yellow)
                            }
                        }
                    }

                    // 单次密码
                    if !engine.oneTimePasswords.isEmpty {
                        PasswordSection(title: "单次密码", subtitle: "用后即焚", icon: "flame.fill", color: .orange) {
                            ForEach(engine.oneTimePasswords) { entry in
                                PasswordRow(
                                    password: entry.password,
                                    badge: entry.markedForDeletion ? "待删" : "🔥",
                                    badgeColor: .orange
                                )
                            }
                        }
                    }

                    // 永久密码
                    PasswordSection(title: "永久密码", subtitle: "\(engine.passwords.count)个", icon: "key.fill", color: .blue) {
                        ForEach(engine.passwords) { entry in
                            PasswordRow(
                                password: entry.password,
                                badge: entry.successCount > 0 ? "\(entry.successCount)次" : nil,
                                badgeColor: .green
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func addPassword() {
        engine.addPassword(newPassword, isOneTime: isOneTime)
        newPassword = ""
    }
}

struct PasswordSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            VStack(spacing: 4) {
                content
            }
            .padding(10)
            .glassEffect(.regular.tint(color.opacity(0.05)))
        }
    }
}

struct PasswordRow: View {
    let password: String
    let badge: String?
    let badgeColor: Color

    var body: some View {
        HStack {
            Text(password)
                .font(.system(.body, design: .monospaced))
            Spacer()
            if let badge = badge {
                Text(badge)
                    .font(.caption)
                    .foregroundColor(badgeColor)
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: engine.clearLogs) {
                    Text("清空")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(engine.logs) { log in
                        LogRow(log: log)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

struct LogRow: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(logColor)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)

            Spacer()

            Text(formatTime(log.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(logColor.opacity(0.1)))
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

// MARK: - 液态玻璃控制栏
struct LiquidGlassControlBar: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var showSettings = false
    @State private var showUpdateLog = false

    var body: some View {
        HStack(spacing: 12) {
            // 输出目录
            Button(action: selectOutputDir) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text(shortenPath(engine.outputDirectory))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.primary)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
            .help("输出目录")

            Spacer()

            // 更新日志
            Button(action: { showUpdateLog.toggle() }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                    .padding(8)
                    .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showUpdateLog) {
                UpdateLogView()
            }

            // 设置
            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gear")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(engine)
                    .frame(width: 260)
                    .padding()
            }

            // 开始/停止按钮
            if engine.isProcessing {
                Button(action: { engine.stopProcessing() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("停止")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(.red))
                    .glassEffect(.regular.tint(.red.opacity(0.3)))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { engine.startProcessing() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("开始解压")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(
                            engine.tasks.filter { $0.status == .pending }.isEmpty
                                ? Color.gray
                                : Color.blue
                        )
                    )
                    .glassEffect(.regular.tint(.blue.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .disabled(engine.tasks.filter { $0.status == .pending }.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

// MARK: - 设置
struct SettingsView: View {
    @EnvironmentObject var engine: UnzipEngine

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("设置")
                    .font(.headline)

                // 性能
                SettingSection(title: "性能", icon: "cpu", color: .blue) {
                    HStack {
                        Text("并发数")
                        Spacer()
                        Stepper("\(engine.maxConcurrent)", value: $engine.maxConcurrent, in: 1...8)
                            .labelsHidden()
                    }
                    Toggle("动态解压", isOn: $engine.dynamicExtract)
                        .help("搜索完一个目录立即开始解压")
                }

                // 检测
                SettingSection(title: "检测", icon: "magnifyingglass", color: .purple) {
                    Toggle("智能排序", isOn: $engine.smartOrder)
                    Toggle("隐写包检测", isOn: $engine.detectSteganography)
                    Toggle("强制隐写检测", isOn: $engine.forceStegoDetect)
                        .help("对所有文件进行隐写检测")
                    Toggle("强制自解压检测", isOn: $engine.forceSelfExtractDetect)
                    Toggle("修复乱码文件名", isOn: $engine.fixEncoding)
                }

                // 递归
                SettingSection(title: "递归", icon: "arrow.triangle.2.circlepath", color: .orange) {
                    Toggle("递归解压嵌套包", isOn: $engine.recursiveExtract)
                    if engine.recursiveExtract {
                        HStack {
                            Text("最大层数")
                            Spacer()
                            Stepper("\(engine.maxRecursiveDepth)", value: $engine.maxRecursiveDepth, in: 1...20)
                                .labelsHidden()
                        }
                        if engine.maxRecursiveDepth > 10 {
                            Text("⚠️ 层数过高可能导致无限循环")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    Toggle("使用临时目录", isOn: $engine.useTempDirectory)
                        .help("先解压到临时目录再移动")
                }

                // 清理
                SettingSection(title: "清理", icon: "trash", color: .red) {
                    Toggle("成功后移到回收站", isOn: $engine.autoCleanup)
                    
                    Button("清理单次密码") { engine.cleanupOneTimePasswords() }
                        .disabled(engine.oneTimePasswords.filter { $0.markedForDeletion }.isEmpty)
                    
                    Button("清空任务列表") { engine.clearTasks() }
                        .disabled(engine.isProcessing)
                }

                // 密码
                SettingSection(title: "密码", icon: "key", color: .cyan) {
                    Button("导入密码...") { importPasswords() }
                    Button("导出密码...") { exportPasswords() }
                }

                // 操作
                SettingSection(title: "操作", icon: "arrow.clockwise", color: .green) {
                    Button("重试失败任务") { engine.retryFailed() }
                        .disabled(engine.failedCount == 0)
                    Button("保存设置") { engine.saveSettings() }
                }
            }
            .font(.subheadline)
        }
    }
}

// MARK: - 设置分组
struct SettingSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .fontWeight(.medium)
            }
            .font(.caption)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.08))
            )
        }
    }
}

// MARK: - 更新日志窗口
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
                    .foregroundColor(.yellow)
                Text("更新日志")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(changelog, id: \.version) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("v\(entry.version)")
                                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                    .foregroundColor(.blue)
                                Text(entry.date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(entry.changes, id: \.self) { change in
                                    Text(change)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular.tint(.blue.opacity(0.05)))
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 320, height: 400)
    }
}
