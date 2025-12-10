import Foundation
import Combine

// MARK: - 密码条目
struct PasswordEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var password: String
    var successCount: Int
    var lastUsed: Date?
    var source: String // permanent=永久, oneTime=单次, cache=缓存, charMatch=字符匹配
    var isOneTime: Bool // 单次密码标记
    var markedForDeletion: Bool // 用后即焚标记
    
    init(password: String, source: String = "permanent", isOneTime: Bool = false) {
        self.id = UUID()
        self.password = password
        self.successCount = 0
        self.lastUsed = nil
        self.source = source
        self.isOneTime = isOneTime
        self.markedForDeletion = false
    }
}

// MARK: - 解压任务
struct UnzipTask: Identifiable {
    let id: UUID
    let filePath: String
    let fileName: String
    var status: TaskStatus
    var progress: Double
    var usedPassword: String?
    var error: String?
    var startTime: Date?
    var endTime: Date?
    var passwordTryCount: Int = 0 // 密码测试计数 (原作者功能)
    var isSteganography: Bool = false // 是否为隐写包
    var isSelfExtract: Bool = false // 是否为自解压
    var outputPath: String? // 实际输出路径
    
    enum TaskStatus: String {
        case pending = "等待中"
        case extracting = "解压中"
        case tryingPasswords = "尝试密码"
        case success = "成功"
        case failed = "失败"
        case cancelled = "已取消"
    }
    
    init(filePath: String) {
        self.id = UUID()
        self.filePath = filePath
        self.fileName = (filePath as NSString).lastPathComponent
        self.status = .pending
        self.progress = 0
    }
    
    // 格式化耗时
    var duration: String? {
        guard let start = startTime, let end = endTime else { return nil }
        let seconds = end.timeIntervalSince(start)
        if seconds < 1 { return "<1s" }
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        return String(format: "%.1fm", seconds / 60)
    }
}

// MARK: - 日志条目
struct LogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
    let details: String?
    
    enum LogLevel: String {
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARN"
        case error = "ERROR"
    }
    
    init(_ level: LogLevel, _ message: String, details: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.message = message
        self.details = details
    }
}

// MARK: - 解压引擎
@MainActor
class UnzipEngine: ObservableObject {
    static let shared = UnzipEngine()
    
    // 状态
    @Published var tasks: [UnzipTask] = []
    @Published var passwords: [PasswordEntry] = [] // 永久密码
    @Published var oneTimePasswords: [PasswordEntry] = [] // 单次密码
    @Published var cachePasswords: [String] = [] // 缓存密码(成功过的)
    @Published var logs: [LogEntry] = []
    @Published var isProcessing = false
    @Published var currentTask: UnzipTask?
    @Published var outputDirectory: String = ""
    @Published var totalTried: Int = 0
    @Published var totalSuccess: Int = 0
    @Published var totalFailed: Int = 0
    
    // 配置
    @Published var maxConcurrent: Int = 4
    @Published var smartOrder: Bool = true // 智能排序密码
    @Published var autoCleanup: Bool = false // 成功后移到回收站
    @Published var detectSteganography: Bool = true // 隐写包检测
    @Published var recursiveExtract: Bool = true // 递归解压嵌套压缩包
    @Published var maxRecursiveDepth: Int = 5 // 最大递归层数
    @Published var fixEncoding: Bool = true // 修复乱码文件名
    @Published var dynamicExtract: Bool = true // 动态解压(搜索完一个目录立即解压)
    @Published var forceStegoDetect: Bool = false // 强制隐写检测 (原作者功能)
    @Published var forceSelfExtractDetect: Bool = false // 强制自解压检测 (原作者功能)
    @Published var stegoExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "mp4", "mkv", "avi", "mp3", "flac"] // 隐写格式列表
    @Published var excludeExtensions: Set<String> = ["txt", "nfo", "url", "lnk"] // 排除格式
    @Published var useTempDirectory: Bool = true // 使用临时目录解压 (原作者功能)
    @Published var autoCloseOnSuccess: Bool = false // 全部成功后自动关闭 (原作者: 命令行模式)
    
    private var taskQueue: [UnzipTask] = []
    private var sessionStartTime: Date?
    private var stoppedForcefully = false
    private var activeCount = 0
    private let fileManager = FileManager.default
    private var sevenZipPath: String?
    
    private init() {
        loadPasswords()
        loadSettings()
        findSevenZip()
        outputDirectory = NSHomeDirectory() + "/Downloads/Unzipped"
        sessionStartTime = Date()
        
        // 处理命令行参数 (原作者功能)
        processCommandLineArguments()
    }
    
    // MARK: - 命令行参数支持 (原作者功能)
    private func processCommandLineArguments() {
        let args = CommandLine.arguments
        guard args.count > 1 else { return }
        
        var filesToAdd: [URL] = []
        for arg in args.dropFirst() {
            let url = URL(fileURLWithPath: arg)
            if fileManager.fileExists(atPath: arg) {
                filesToAdd.append(url)
            }
        }
        
        if !filesToAdd.isEmpty {
            log(.info, "命令行传入 \(filesToAdd.count) 个文件")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.addFiles(filesToAdd)
            }
        }
    }
    
    // MARK: - 设置持久化
    func loadSettings() {
        let url = getSettingsFileURL()
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return
        }
        
        maxConcurrent = settings.maxConcurrent
        smartOrder = settings.smartOrder
        autoCleanup = settings.autoCleanup
        detectSteganography = settings.detectSteganography
        recursiveExtract = settings.recursiveExtract
        maxRecursiveDepth = settings.maxRecursiveDepth
        fixEncoding = settings.fixEncoding
        dynamicExtract = settings.dynamicExtract
        forceStegoDetect = settings.forceStegoDetect
        forceSelfExtractDetect = settings.forceSelfExtractDetect
        useTempDirectory = settings.useTempDirectory
        if !settings.outputDirectory.isEmpty {
            outputDirectory = settings.outputDirectory
        }
    }
    
    func saveSettings() {
        let settings = Settings(
            maxConcurrent: maxConcurrent,
            smartOrder: smartOrder,
            autoCleanup: autoCleanup,
            detectSteganography: detectSteganography,
            recursiveExtract: recursiveExtract,
            maxRecursiveDepth: maxRecursiveDepth,
            fixEncoding: fixEncoding,
            dynamicExtract: dynamicExtract,
            forceStegoDetect: forceStegoDetect,
            forceSelfExtractDetect: forceSelfExtractDetect,
            useTempDirectory: useTempDirectory,
            outputDirectory: outputDirectory
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: getSettingsFileURL())
        }
    }
    
    private func getSettingsFileURL() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("UnzipDict")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }
    
    // MARK: - 7z 路径检测
    private func findSevenZip() {
        let paths = [
            "/opt/homebrew/bin/7z",
            "/usr/local/bin/7z",
            "/opt/homebrew/bin/7zz",
            "/usr/local/bin/7zz"
        ]
        for path in paths {
            if fileManager.fileExists(atPath: path) {
                sevenZipPath = path
                log(.info, "找到 7z: \(path)")
                return
            }
        }
        log(.warning, "未找到 7z，请安装: brew install p7zip")
    }
    
    // MARK: - 密码管理
    func loadPasswords() {
        let url = getPasswordsFileURL()
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([PasswordEntry].self, from: data) else {
            // 加载默认密码
            loadDefaultPasswords()
            return
        }
        passwords = loaded
        log(.info, "加载 \(passwords.count) 个密码")
    }
    
    func savePasswords() {
        let url = getPasswordsFileURL()
        if let data = try? JSONEncoder().encode(passwords) {
            try? data.write(to: url)
        }
    }
    
    func addPassword(_ password: String, isOneTime: Bool = false) {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 检查重复
        let allPasswords = passwords + oneTimePasswords
        if allPasswords.contains(where: { $0.password == trimmed }) {
            log(.info, "密码已存在: \(trimmed)")
            return
        }
        
        let entry = PasswordEntry(password: trimmed, source: isOneTime ? "oneTime" : "permanent", isOneTime: isOneTime)
        
        if isOneTime {
            oneTimePasswords.insert(entry, at: 0)
            log(.success, "添加单次密码: \(trimmed)")
        } else {
            passwords.insert(entry, at: 0)
            log(.success, "添加永久密码: \(trimmed)")
        }
        savePasswords()
    }
    
    func recordSuccess(password: String) {
        // 添加到缓存密码最前面
        cachePasswords.removeAll { $0 == password }
        cachePasswords.insert(password, at: 0)
        if cachePasswords.count > 20 { cachePasswords.removeLast() }
        
        // 更新永久密码统计
        if let index = passwords.firstIndex(where: { $0.password == password }) {
            passwords[index].successCount += 1
            passwords[index].lastUsed = Date()
            if smartOrder {
                passwords.sort { $0.successCount > $1.successCount }
            }
        }
        
        // 单次密码标记删除
        if let index = oneTimePasswords.firstIndex(where: { $0.password == password }) {
            oneTimePasswords[index].markedForDeletion = true
        }
        
        savePasswords()
    }
    
    func cleanupOneTimePasswords() {
        oneTimePasswords.removeAll { $0.markedForDeletion }
        savePasswords()
    }
    
    private func getPasswordsFileURL() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("UnzipDict")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("passwords.json")
    }
    
    private func loadDefaultPasswords() {
        // 常见密码
        let defaults = [
            "123456", "password", "123", "1234", "12345678",
            "蓝蝶绯翼", "菠萝", "cangku.one", "gugua", "hgp",
            "@vposy", "2345", "dabaishua", "114514", "6666"
        ]
        passwords = defaults.map { PasswordEntry(password: $0, source: "default") }
        savePasswords()
    }
    
    // MARK: - 4层密码队列 (原作者策略)
    // 顺序: 字符匹配 → 缓存 → 单次 → 永久
    func getPasswordQueue(for fileName: String) -> [String] {
        var queue: [String] = []
        
        // 1. 字符匹配密码 (最优先)
        queue.append("") // 空密码
        let baseName = (fileName as NSString).deletingPathExtension
        queue.append(baseName) // 文件名
        // 提取括号内容 如 "aaa(b).zip" → "b"
        if let match = baseName.range(of: "\\(([^)]+)\\)", options: .regularExpression) {
            let content = String(baseName[match]).dropFirst().dropLast()
            queue.append(String(content))
        }
        
        // 2. 缓存密码 (最近成功的)
        queue.append(contentsOf: cachePasswords)
        
        // 3. 单次密码
        queue.append(contentsOf: oneTimePasswords.filter { !$0.markedForDeletion }.map { $0.password })
        
        // 4. 永久密码 (智能排序)
        var sorted = passwords
        if smartOrder {
            sorted.sort { a, b in
                if a.successCount != b.successCount { return a.successCount > b.successCount }
                if let aDate = a.lastUsed, let bDate = b.lastUsed { return aDate > bDate }
                return a.password.count < b.password.count
            }
        }
        queue.append(contentsOf: sorted.map { $0.password })
        
        // 去重
        var seen = Set<String>()
        return queue.filter { seen.insert($0).inserted }
    }
    
    // 兼容旧接口
    func getSortedPasswords() -> [String] {
        return getPasswordQueue(for: "")
    }
    
    // MARK: - 任务管理
    func addFiles(_ urls: [URL]) {
        let supportedExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz", "exe"]
        
        for url in urls {
            if url.hasDirectoryPath {
                // 递归扫描目录 (原作者: 动态解压)
                scanDirectory(url)
            } else {
                let ext = url.pathExtension.lowercased()
                
                // 检查排除格式 (原作者功能)
                if excludeExtensions.contains(ext) {
                    continue
                }
                
                // 检查分卷压缩包
                let (isMultiPart, isFirstPart) = isMultiPartArchive(url.path)
                if isMultiPart && !isFirstPart {
                    log(.info, "跳过非首包: \(url.lastPathComponent)")
                    continue
                }
                
                if supportedExtensions.contains(ext) {
                    addTask(for: url)
                } else if detectSteganography || forceStegoDetect {
                    // 检查是否为隐写格式
                    if stegoExtensions.contains(ext) || forceStegoDetect {
                        Task {
                            if await detectSteganographyArchive(url.path) {
                                await MainActor.run {
                                    addTask(for: url, isSteganography: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func addTask(for url: URL, isSteganography: Bool = false) {
        // 检查重复
        if tasks.contains(where: { $0.filePath == url.path }) {
            return
        }
        
        var task = UnzipTask(filePath: url.path)
        task.isSteganography = isSteganography
        
        // 检测自解压文件 (原作者功能)
        let ext = url.pathExtension.lowercased()
        if ext == "exe" {
            task.isSelfExtract = true
            log(.info, "检测到自解压: \(task.fileName)")
        } else if isSteganography {
            log(.info, "检测到隐写包: \(task.fileName)")
        }
        
        tasks.append(task)
        taskQueue.append(task)
        log(.info, "添加任务: \(task.fileName)")
        
        // 动态解压模式
        if dynamicExtract && !isProcessing && !taskQueue.isEmpty {
            startProcessing()
        }
    }
    
    // 递归扫描目录 (原作者功能)
    private func scanDirectory(_ url: URL, depth: Int = 0) {
        guard depth < 10 else { return } // 防止无限递归
        
        let supportedExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz", "exe"]
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if isDir {
                scanDirectory(item, depth: depth + 1)
            } else {
                let ext = item.pathExtension.lowercased()
                
                let (isMultiPart, isFirstPart) = isMultiPartArchive(item.path)
                if isMultiPart && !isFirstPart {
                    continue
                }
                
                if supportedExtensions.contains(ext) {
                    addTask(for: item)
                }
            }
        }
    }
    
    func startProcessing() {
        guard !isProcessing, !taskQueue.isEmpty else { return }
        isProcessing = true
        log(.info, "开始处理 \(taskQueue.count) 个任务")
        processNextBatch()
    }
    
    func stopProcessing() {
        isProcessing = false
        stoppedForcefully = false
        taskQueue.removeAll()
        log(.warning, "已停止处理")
    }
    
    // 强制停止 (原作者功能)
    func forceStop() {
        isProcessing = false
        stoppedForcefully = true
        taskQueue.removeAll()
        log(.error, "强制停止")
    }
    
    // 重试失败的任务 (原作者功能)
    func retryFailed() {
        let failedTasks = tasks.filter { $0.status == .failed }
        for var task in failedTasks {
            task.status = .pending
            task.error = nil
            task.progress = 0
            taskQueue.append(task)
            updateTask(task)
        }
        if !failedTasks.isEmpty {
            log(.info, "重试 \(failedTasks.count) 个失败任务")
            startProcessing()
        }
    }
    
    // 清空任务列表
    func clearTasks() {
        tasks.removeAll()
        taskQueue.removeAll()
        totalTried = 0
        totalSuccess = 0
        totalFailed = 0
    }
    
    private func processNextBatch() {
        guard isProcessing else { return }
        
        while activeCount < maxConcurrent, let task = taskQueue.first {
            taskQueue.removeFirst()
            activeCount += 1
            
            Task {
                await processTask(task)
                activeCount -= 1
                processNextBatch()
                
                if activeCount == 0 && taskQueue.isEmpty {
                    isProcessing = false
                    log(.success, "全部完成: 成功 \(totalSuccess), 失败 \(totalFailed)")
                }
            }
        }
    }
    
    // MARK: - 解压逻辑
    private func processTask(_ task: UnzipTask) async {
        var task = task
        task.status = .extracting
        task.startTime = Date()
        updateTask(task)
        currentTask = task
        
        // 创建输出目录 (防覆盖)
        let baseName = (task.fileName as NSString).deletingPathExtension
        var outputDir = outputDirectory + "/" + baseName
        
        // 隐写包特殊命名 (原作者: 视频名+"~EXT")
        if task.isSteganography {
            outputDir = outputDirectory + "/" + baseName + "~EXT"
        }
        
        // 防覆盖: 如果目录已存在，添加数字后缀 (原作者功能)
        outputDir = getUniqueOutputPath(outputDir)
        task.outputPath = outputDir
        updateTask(task)
        
        try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        // 1. 先尝试无密码
        if await tryExtract(task.filePath, to: outputDir, password: nil) {
            task.status = .success
            task.usedPassword = nil
            task.endTime = Date()
            updateTask(task)
            totalSuccess += 1
            log(.success, "\(task.fileName) - 无密码解压成功")
            return
        }
        
        // 2. 使用4层密码队列尝试
        task.status = .tryingPasswords
        updateTask(task)
        
        let passwordQueue = getPasswordQueue(for: task.fileName)
        let total = passwordQueue.count
        
        for (index, password) in passwordQueue.enumerated() {
            guard isProcessing else {
                task.status = .cancelled
                updateTask(task)
                return
            }
            
            task.progress = Double(index + 1) / Double(total)
            task.passwordTryCount = index + 1
            totalTried += 1
            updateTask(task)
            
            if await tryExtract(task.filePath, to: outputDir, password: password) {
                task.status = .success
                task.usedPassword = password.isEmpty ? "(无密码)" : password
                task.endTime = Date()
                updateTask(task)
                totalSuccess += 1
                if !password.isEmpty { recordSuccess(password: password) }
                log(.success, "\(task.fileName) - 密码: \(password.isEmpty ? "无" : password) [第\(index+1)次尝试]")
                
                // 后处理
                fixGarbledFilenames(in: outputDir)
                await extractNestedArchives(in: outputDir)
                
                // 移到回收站
                if autoCleanup {
                    moveToTrash(task.filePath)
                }
                return
            }
        }
        
        // 3. 全部失败
        task.status = .failed
        task.error = "密码不在字典中"
        task.endTime = Date()
        updateTask(task)
        totalFailed += 1
        log(.error, "\(task.fileName) - 解压失败")
    }
    
    private func tryExtract(_ archive: String, to outputDir: String, password: String?) async -> Bool {
        guard let sevenZip = sevenZipPath else { return false }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sevenZip)
        
        var args = ["x", "-y", "-o\(outputDir)", archive]
        if let pw = password {
            args.insert("-p\(pw)", at: 1)
        }
        process.arguments = args
        
        // 静默执行
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func updateTask(_ task: UnzipTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
        if currentTask?.id == task.id {
            currentTask = task
        }
    }
    
    // MARK: - 日志
    func log(_ level: LogEntry.LogLevel, _ message: String, details: String? = nil) {
        let entry = LogEntry(level, message, details: details)
        logs.insert(entry, at: 0)
        
        // 限制日志数量
        if logs.count > 500 {
            logs.removeLast()
        }
        
        // 写入文件
        writeLogToFile(entry)
    }
    
    private func writeLogToFile(_ entry: LogEntry) {
        let formatter = DateFormatter()
        // 兼容原作者日志格式: 2025-06-10--13:02:14 -> 消息
        formatter.dateFormat = "yyyy-MM-dd--HH:mm:ss"
        let line = "\(formatter.string(from: entry.timestamp)) -> \(entry.message)\n"
        
        let url = getPasswordsFileURL().deletingLastPathComponent().appendingPathComponent("log.txt")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    // 启动时列举密码 (原作者功能)
    func logPasswordList() {
        log(.info, "----------列举密码----------")
        for entry in passwords.prefix(20) {
            let countStr = String(format: "%06d", entry.successCount)
            log(.info, " 密码使用次数:\(countStr) : \(entry.password)")
        }
        if passwords.count > 20 {
            log(.info, " ... 还有 \(passwords.count - 20) 个密码")
        }
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    // MARK: - 移到回收站 (原作者功能)
    func moveToTrash(_ path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
            log(.info, "已移到回收站: \(url.lastPathComponent)")
        } catch {
            log(.warning, "移到回收站失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 分卷压缩包检测 (原作者功能)
    func isMultiPartArchive(_ path: String) -> (isMultiPart: Bool, isFirstPart: Bool) {
        let fileName = (path as NSString).lastPathComponent.lowercased()
        
        // 常见分卷格式
        let patterns = [
            "part1\\.rar$", "part01\\.rar$", "part001\\.rar$",
            "\\.001$", "\\.z01$", "\\.7z\\.001$",
            "\\.r00$", "\\.zip\\.001$"
        ]
        
        for pattern in patterns {
            if fileName.range(of: pattern, options: .regularExpression) != nil {
                return (true, true)
            }
        }
        
        // 非首包
        let nonFirstPatterns = [
            "part[2-9]\\d*\\.rar$", "part0[2-9]\\.rar$",
            "\\.[0-9]{3}$", "\\.r[0-9]{2}$"
        ]
        for pattern in nonFirstPatterns {
            if fileName.range(of: pattern, options: .regularExpression) != nil {
                return (true, false)
            }
        }
        
        return (false, true)
    }
    
    // MARK: - 隐写包检测 (原作者功能)
    func detectSteganographyArchive(_ path: String) async -> Bool {
        guard detectSteganography else { return false }
        guard let sevenZip = sevenZipPath else { return false }
        
        let ext = (path as NSString).pathExtension.lowercased()
        let stegoExtensions = ["jpg", "jpeg", "png", "gif", "webp", "mp4", "mkv", "avi"]
        guard stegoExtensions.contains(ext) else { return false }
        
        // 用7z测试是否为压缩包
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sevenZip)
        process.arguments = ["t", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    // MARK: - 编码检测与修复 (原作者功能)
    // 检测并修复乱码文件名 (日文SHIFT-JIS, 中文GB2312等)
    func fixGarbledFilenames(in directory: String) {
        guard fixEncoding else { return }
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { return }
        
        for filename in contents {
            let fullPath = (directory as NSString).appendingPathComponent(filename)
            
            // 检测是否为乱码 (包含替换字符或无法识别的字节序列)
            if let fixedName = tryFixEncoding(filename) {
                let newPath = (directory as NSString).appendingPathComponent(fixedName)
                do {
                    try fileManager.moveItem(atPath: fullPath, toPath: newPath)
                    log(.info, "修复文件名: \(filename) → \(fixedName)")
                } catch {
                    // 忽略重命名失败
                }
            }
            
            // 递归处理子目录
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                fixGarbledFilenames(in: fullPath)
            }
        }
    }
    
    private func tryFixEncoding(_ filename: String) -> String? {
        // 检测常见乱码模式
        let garbledPatterns = ["ï¿½", "�", "ÃƒÂ", "Ã©", "Ã¨"]
        let hasGarbled = garbledPatterns.contains { filename.contains($0) }
        
        guard hasGarbled else { return nil }
        
        // 尝试不同编码转换
        let encodings: [String.Encoding] = [
            .shiftJIS,           // 日文
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))), // 中文GB
            .utf8
        ]
        
        for encoding in encodings {
            if let data = filename.data(using: .isoLatin1),
               let decoded = String(data: data, encoding: encoding),
               !decoded.contains("�") {
                return decoded
            }
        }
        
        return nil
    }
    
    // MARK: - 递归解压嵌套压缩包 (原作者功能)
    func extractNestedArchives(in directory: String, depth: Int = 0) async {
        guard recursiveExtract else { return }
        guard depth < maxRecursiveDepth else {
            log(.warning, "达到最大递归层数: \(maxRecursiveDepth)")
            return
        }
        
        let supportedExtensions = ["zip", "rar", "7z", "tar", "gz"]
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { return }
        
        for filename in contents {
            let fullPath = (directory as NSString).appendingPathComponent(filename)
            let ext = (filename as NSString).pathExtension.lowercased()
            
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)
            
            if isDir.boolValue {
                await extractNestedArchives(in: fullPath, depth: depth)
            } else if supportedExtensions.contains(ext) {
                // 发现嵌套压缩包
                log(.info, "发现嵌套压缩包: \(filename) [层级\(depth + 1)]")
                
                let nestedOutputDir = (fullPath as NSString).deletingPathExtension
                
                // 尝试解压
                if await tryExtract(fullPath, to: nestedOutputDir, password: nil) {
                    // 删除已解压的压缩包
                    try? fileManager.removeItem(atPath: fullPath)
                    // 继续递归
                    await extractNestedArchives(in: nestedOutputDir, depth: depth + 1)
                }
            }
        }
    }
    
    // MARK: - 密码测试 (原作者功能: 快速测试密码是否正确)
    func testPassword(_ archive: String, password: String) async -> Bool {
        guard let sevenZip = sevenZipPath else { return false }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sevenZip)
        // 使用 t 命令测试，只解压第一个文件到内存
        process.arguments = [
            "t",
            "-p\(password)",
            archive
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    // MARK: - 统计信息
    var pendingCount: Int { tasks.filter { $0.status == .pending }.count }
    var processingCount: Int { tasks.filter { $0.status == .extracting || $0.status == .tryingPasswords }.count }
    var completedCount: Int { tasks.filter { $0.status == .success }.count }
    var failedCount: Int { tasks.filter { $0.status == .failed }.count }
    
    // MARK: - 输出路径防覆盖 (原作者功能)
    private func getUniqueOutputPath(_ basePath: String) -> String {
        var path = basePath
        var counter = 1
        
        while fileManager.fileExists(atPath: path) {
            // 添加父目录名或数字后缀
            path = "\(basePath)_\(counter)"
            counter += 1
            
            if counter > 100 {
                // 防止无限循环
                let timestamp = Int(Date().timeIntervalSince1970)
                return "\(basePath)_\(timestamp)"
            }
        }
        
        return path
    }
    
    // MARK: - 获取压缩包信息 (原作者功能)
    func getArchiveInfo(_ path: String) async -> ArchiveInfo? {
        guard let sevenZip = sevenZipPath else { return nil }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sevenZip)
        process.arguments = ["l", "-slt", path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            
            return parseArchiveInfo(output)
        } catch {
            return nil
        }
    }
    
    private func parseArchiveInfo(_ output: String) -> ArchiveInfo {
        var info = ArchiveInfo()
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("Type = ") {
                info.type = String(line.dropFirst(7))
            } else if line.hasPrefix("Physical Size = ") {
                info.physicalSize = Int64(String(line.dropFirst(16))) ?? 0
            } else if line.hasPrefix("Files = ") {
                info.fileCount = Int(String(line.dropFirst(8))) ?? 0
            } else if line.hasPrefix("Folders = ") {
                info.folderCount = Int(String(line.dropFirst(10))) ?? 0
            } else if line.hasPrefix("Encrypted = +") {
                info.isEncrypted = true
            }
        }
        
        return info
    }
    
    // MARK: - 导入/导出密码 (原作者功能)
    // 兼容原作者格式: "密码\t次数" 或纯密码
    func exportPasswords(to url: URL) {
        var lines: [String] = []
        for entry in passwords {
            // 导出为原作者格式: 密码\t次数
            lines.append("\(entry.password)\t\(entry.successCount)")
        }
        let content = lines.joined(separator: "\n")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        log(.success, "导出 \(passwords.count) 个密码")
    }
    
    func importPasswords(from url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            log(.error, "无法读取密码文件")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        var imported = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // 解析原作者格式: "密码\t次数" 或 "密码    次数"
            var password = trimmed
            var successCount = 0
            
            // 尝试分割 (tab或多个空格)
            if let tabRange = trimmed.range(of: "\t") {
                password = String(trimmed[..<tabRange.lowerBound])
                if let count = Int(trimmed[tabRange.upperBound...].trimmingCharacters(in: .whitespaces)) {
                    successCount = count
                }
            } else if let match = trimmed.range(of: "\\s{2,}\\d+$", options: .regularExpression) {
                // 多个空格+数字结尾
                password = String(trimmed[..<match.lowerBound])
                if let count = Int(trimmed[match].trimmingCharacters(in: .whitespaces)) {
                    successCount = count
                }
            }
            
            password = password.trimmingCharacters(in: .whitespaces)
            
            // 检查重复
            if !password.isEmpty && !passwords.contains(where: { $0.password == password }) {
                var entry = PasswordEntry(password: password, source: "imported")
                entry.successCount = successCount
                passwords.append(entry)
                imported += 1
            }
        }
        
        // 按成功次数排序
        if smartOrder {
            passwords.sort { $0.successCount > $1.successCount }
        }
        
        savePasswords()
        log(.success, "导入 \(imported) 个新密码")
    }
}

// MARK: - 压缩包信息
struct ArchiveInfo {
    var type: String = ""
    var physicalSize: Int64 = 0
    var fileCount: Int = 0
    var folderCount: Int = 0
    var isEncrypted: Bool = false
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: physicalSize)
    }
}

// MARK: - 设置结构体
struct Settings: Codable {
    var maxConcurrent: Int
    var smartOrder: Bool
    var autoCleanup: Bool
    var detectSteganography: Bool
    var recursiveExtract: Bool
    var maxRecursiveDepth: Int
    var fixEncoding: Bool
    var dynamicExtract: Bool
    var forceStegoDetect: Bool
    var forceSelfExtractDetect: Bool
    var useTempDirectory: Bool
    var outputDirectory: String
}

// MARK: - 会话统计 (原作者功能)
struct SessionStats {
    var startTime: Date
    var totalFiles: Int = 0
    var processedFiles: Int = 0
    var successFiles: Int = 0
    var failedFiles: Int = 0
    var totalPasswordTries: Int = 0
    
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var formattedElapsedTime: String {
        let seconds = Int(elapsedTime)
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            return "\(seconds / 60)分\(seconds % 60)秒"
        } else {
            return "\(seconds / 3600)时\((seconds % 3600) / 60)分"
        }
    }
    
    var estimatedTimeRemaining: String? {
        guard processedFiles > 0, totalFiles > processedFiles else { return nil }
        let avgTime = elapsedTime / Double(processedFiles)
        let remaining = avgTime * Double(totalFiles - processedFiles)
        let seconds = Int(remaining)
        if seconds < 60 {
            return "约\(seconds)秒"
        } else {
            return "约\(seconds / 60)分钟"
        }
    }
}
