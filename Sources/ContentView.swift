import SwiftUI
import UniformTypeIdentifiers

// MARK: - 主视图
struct ContentView: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var selectedTab = 0
    @State private var isDragging = false
    @Namespace private var animation

    var body: some View {
        ZStack {
            // 动态背景
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    .blue.opacity(0.08), .purple.opacity(0.05), .cyan.opacity(0.06),
                    .indigo.opacity(0.04), .clear, .teal.opacity(0.05),
                    .purple.opacity(0.06), .blue.opacity(0.04), .cyan.opacity(0.08)
                ]
            )
            .ignoresSafeArea()
            .blur(radius: 60)

            VStack(spacing: 0) {
                GlassHeader(selectedTab: $selectedTab, animation: animation)
                    .environmentObject(engine)

                GlassDropZone(isDragging: $isDragging)
                    .environmentObject(engine)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

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
    var animation: Namespace.ID

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                MiniStat(value: engine.totalSuccess, icon: "checkmark.circle.fill", color: .green)
                MiniStat(value: engine.totalFailed, icon: "xmark.circle.fill", color: .red)
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach(Array(zip([0, 1, 2], [("任务", "list.bullet"), ("密码", "key.fill"), ("日志", "doc.text")])), id: \.0) { index, item in
                    GlassTab(title: item.0, icon: item.1, isSelected: selectedTab == index, animation: animation) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedTab = index }
                    }
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive())

            Spacer()

            HStack(spacing: 6) {
                if !engine.cachePasswords.isEmpty {
                    Label("\(engine.cachePasswords.count)", systemImage: "bolt.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.yellow)
                }
                Label("\(engine.passwords.count)", systemImage: "key")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect()
    }
}

struct MiniStat: View {
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(value > 0 ? color : color.opacity(0.4))
            Text("\(value)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(value > 0 ? .primary : .tertiary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(color.opacity(value > 0 ? 0.12 : 0.05)))
    }
}

struct GlassTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.background.opacity(0.9))
                        .matchedGeometryEffect(id: "tab", in: animation)
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
            RoundedRectangle(cornerRadius: 16)
                .fill(.clear)
                .glassEffect(.regular.tint(isDragging ? .blue.opacity(0.15) : .clear))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isDragging ? Color.blue : Color.primary.opacity(0.1),
                            style: StrokeStyle(lineWidth: isDragging ? 2 : 1, dash: isDragging ? [] : [5, 4])
                        )
                }

            VStack(spacing: 6) {
                Image(systemName: isDragging ? "arrow.down.circle.fill" : "arrow.down.doc")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(isDragging ? .blue : .secondary)
                    .symbolEffect(.bounce, value: isDragging)

                Text("拖放压缩文件")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isDragging ? .primary : .secondary)

                Text("zip · rar · 7z · tar.gz")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 88)
        .scaleEffect(isDragging ? 1.02 : 1)
        .animation(.spring(response: 0.3), value: isDragging)
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

    enum ViewMode { case list, tree }

    var body: some View {
        VStack(spacing: 0) {
            StatsBar(viewMode: $viewMode)
                .environmentObject(engine)

            if engine.tasks.isEmpty {
                ContentUnavailableView {
                    Label("暂无任务", systemImage: "tray")
                } description: {
                    Text("拖放压缩文件开始解压")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewMode == .list {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(engine.tasks) { task in
                            TaskCard(task: task)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            } else {
                TreeView().environmentObject(engine)
            }
        }
    }
}

// MARK: - 统计栏
struct StatsBar: View {
    @EnvironmentObject var engine: UnzipEngine
    @Binding var viewMode: TaskListView.ViewMode

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                StatItem(label: "待处理", value: engine.pendingCount, color: .secondary)
                StatItem(label: "处理中", value: engine.processingCount, color: .blue)
                StatItem(label: "完成", value: engine.completedCount, color: .green)
                StatItem(label: "失败", value: engine.failedCount, color: .red)
            }

            Spacer()

            if engine.isProcessing, let remaining = engine.estimatedRemainingTime {
                Label(remaining, systemImage: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.tint(.orange.opacity(0.1)))
            }

            HStack(spacing: 2) {
                ViewModeButton(icon: "list.bullet", isSelected: viewMode == .list) { viewMode = .list }
                ViewModeButton(icon: "list.bullet.indent", isSelected: viewMode == .tree) { viewMode = .tree }
            }
            .padding(3)
            .glassEffect(.regular.interactive())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

struct StatItem: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(value > 0 ? color : .quaternary)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
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
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .primary : .tertiary)
                .frame(width: 26, height: 22)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5)
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
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            statusIcon.frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.fileName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(1)

                    if task.isSteganography {
                        TagBadge(text: "隐写", color: .purple)
                    }
                    if task.isSelfExtract {
                        TagBadge(text: "自解压", color: .orange)
                    }
                }

                HStack(spacing: 6) {
                    Text(task.status.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(statusColor)

                    if let password = task.usedPassword {
                        Label(password, systemImage: "key.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                    }

                    if task.passwordTryCount > 0 && task.status == .tryingPasswords {
                        Text("#\(task.passwordTryCount)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    if let duration = task.duration {
                        Text(duration)
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }

                    if let error = task.error {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if task.status == .tryingPasswords {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 50)
                    .tint(.blue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive())
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.spring(response: 0.25), value: isHovered)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    var statusIcon: some View {
        switch task.status {
        case .pending:
            Circle()
                .fill(.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
        case .extracting, .tryingPasswords:
            ProgressView()
                .scaleEffect(0.55)
        case .success:
            Circle()
                .fill(.green.opacity(0.15))
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                }
        case .failed:
            Circle()
                .fill(.red.opacity(0.15))
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.red)
                }
        case .cancelled:
            Circle()
                .fill(.orange.opacity(0.15))
                .overlay {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
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
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
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
            LazyVStack(spacing: 10) {
                ForEach(groupedTasks.keys.sorted(), id: \.self) { folder in
                    FolderSection(folderName: folder, tasks: groupedTasks[folder] ?? [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
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
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)

                    Text(folderName)
                        .font(.system(size: 12, weight: .medium))

                    Text("\(tasks.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if successCount > 0 {
                        Label("\(successCount)", systemImage: "checkmark")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                    }

                    if failedCount > 0 {
                        Label("\(failedCount)", systemImage: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(tasks) { task in
                        TreeFileItem(task: task)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }
}

struct TreeFileItem: View {
    let task: UnzipTask

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(.secondary.opacity(0.15))
                .frame(width: 1)

            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(task.fileName)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)

            Spacer()

            if let pw = task.usedPassword {
                Text(pw)
                    .font(.system(size: 9))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    var statusColor: Color {
        switch task.status {
        case .pending: return .secondary.opacity(0.3)
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
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField("添加密码...", text: $newPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isFocused)
                        .onSubmit { addPassword() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive())

                Toggle(isOn: $isOneTime) {
                    Image(systemName: isOneTime ? "flame.fill" : "flame")
                        .font(.system(size: 11))
                        .foregroundStyle(isOneTime ? .orange : .tertiary)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .help(isOneTime ? "单次密码" : "永久密码")

                Button(action: addPassword) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(newPassword.isEmpty ? .tertiary : .blue)
                }
                .buttonStyle(.plain)
                .disabled(newPassword.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            ScrollView {
                LazyVStack(spacing: 14) {
                    if !engine.cachePasswords.isEmpty {
                        PasswordGroup(title: "缓存", subtitle: "最近成功", icon: "bolt.fill", color: .yellow) {
                            ForEach(engine.cachePasswords, id: \.self) { pw in
                                PasswordItem(password: pw, badge: "⚡", badgeColor: .yellow)
                            }
                        }
                    }

                    if !engine.oneTimePasswords.isEmpty {
                        PasswordGroup(title: "单次", subtitle: "用后即焚", icon: "flame.fill", color: .orange) {
                            ForEach(engine.oneTimePasswords) { entry in
                                PasswordItem(password: entry.password, badge: entry.markedForDeletion ? "待删" : "🔥", badgeColor: .orange)
                            }
                        }
                    }

                    PasswordGroup(title: "永久", subtitle: "\(engine.passwords.count)个", icon: "key.fill", color: .blue) {
                        ForEach(engine.passwords) { entry in
                            PasswordItem(password: entry.password, badge: entry.successCount > 0 ? "\(entry.successCount)次" : nil, badgeColor: .green)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 4) {
                content
            }
            .padding(10)
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
                .font(.system(size: 12, design: .monospaced))
            Spacer()
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10))
                    .foregroundStyle(badgeColor)
            }
        }
        .padding(.vertical, 3)
    }
}


// MARK: - 日志列表
struct LogListView: View {
    @EnvironmentObject var engine: UnzipEngine

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("日志")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("清空") { engine.clearLogs() }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if engine.logs.isEmpty {
                ContentUnavailableView {
                    Label("暂无日志", systemImage: "doc.text")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(engine.logs) { log in
                            LogItem(log: log)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

struct LogItem: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(logColor)
                .frame(width: 6, height: 6)
                .padding(.top, 4)

            Text(log.message)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(2)

            Spacer()

            Text(formatTime(log.timestamp))
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(logColor.opacity(0.06)))
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
        HStack(spacing: 12) {
            Button(action: selectOutputDir) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                    Text(shortenPath(engine.outputDirectory))
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)

            Spacer()

            Button { showUpdateLog.toggle() } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showUpdateLog) {
                UpdateLogView()
            }

            Button { showSettings.toggle() } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSettings) {
                SettingsView().environmentObject(engine)
            }

            if engine.isProcessing {
                Button { engine.stopProcessing() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("停止")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.red.gradient))
                }
                .buttonStyle(.plain)
            } else {
                Button { engine.startProcessing() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("开始")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(engine.pendingCount > 0 ? Color.blue.gradient : Color.gray.gradient))
                }
                .buttonStyle(.plain)
                .disabled(engine.pendingCount == 0)
            }
        }
        .padding(.horizontal, 20)
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

// MARK: - 设置视图
struct SettingsView: View {
    @EnvironmentObject var engine: UnzipEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("设置")
                    .font(.system(size: 14, weight: .bold))

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
            .font(.system(size: 11))
        }
        .frame(width: 260)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(color.opacity(0.05)))
        }
    }
}

// MARK: - 更新日志
struct UpdateLogView: View {
    @Environment(\.dismiss) var dismiss

    let changelog: [(version: String, date: String, changes: [String])] = [
        ("1.1.0", "2025-12-10", [
            "🎨 全新液态玻璃 UI 设计",
            "✨ MeshGradient 动态背景",
            "✨ 优化视觉层次和间距",
            "✨ 更流畅的动画效果",
            "✨ 数字过渡动画"
        ]),
        ("1.0.0", "2025-12-10", [
            "🎉 首个 macOS 版本发布",
            "✨ 4层密码队列",
            "✨ 智能密码排序",
            "✨ 隐写包检测",
            "✨ 递归解压嵌套包",
            "✨ 乱码文件名修复",
            "✨ 悬浮密码输入窗口"
        ])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("更新日志", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(changelog, id: \.version) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("v\(entry.version)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Text(entry.date)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(entry.changes, id: \.self) { change in
                                    Text(change)
                                        .font(.system(size: 10))
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
        .frame(width: 300, height: 360)
    }
}
