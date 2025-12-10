# UnzipDict

> A native macOS archive extraction tool with intelligent password dictionary automation. Inspired by the Windows utility "解TM的压" (UnzipTM).

**English** | [中文](#中文)

## Features

- **4-Layer Password Queue**: Character matching → Cache → One-time → Permanent
- **Smart Sorting**: Prioritizes passwords by success count
- **Steganography Detection**: Detects hidden archives in images/videos
- **Multi-part Archive Support**: Auto-identifies and skips non-first volumes
- **Recursive Extraction**: Automatically extracts nested archives
- **Filename Encoding Fix**: Auto-repairs garbled Japanese/Chinese filenames
- **Dynamic Extraction**: Starts extraction immediately after directory scan
- **Floating Password Input**: Add passwords anytime via menu bar
- **Native Frosted Glass UI**: macOS 26 Tahoe design with MeshGradient backgrounds
- **Concurrent Processing**: Configurable parallel extraction (1-8 threads)
- **Supported Formats**: ZIP, RAR, 7Z, TAR, GZ, BZ2, XZ, TGZ, EXE (self-extracting)

## Requirements

- macOS 26.0+
- 7-Zip: `brew install p7zip`

## Installation

```bash
git clone https://github.com/nowaytouse/UnzipDict.git
cd UnzipDict
swift build -c release
open .build/release/UnzipDict
```

## Usage

1. **Drag & Drop**: Drop archive files or folders into the window
2. **Start**: Click "开始" (Start) button
3. **Floating Input**: Use menu bar icon to show floating password input
4. **Monitor**: Track progress in Tasks/Passwords/Logs tabs

## Password Management

### 4-Layer Queue Strategy

Passwords are tried in this order:

1. **Character Matching** (Highest Priority)
   - Empty password
   - Filename as password
   - Content in parentheses: `archive(password).zip` → tries "password"

2. **Cache Passwords** (Recently Successful)
   - Last 20 successful passwords
   - Automatically populated

3. **One-Time Passwords**
   - Marked for deletion after use
   - Useful for temporary passwords

4. **Permanent Passwords** (Lowest Priority)
   - Sorted by success count
   - Can be imported/exported

### Import/Export

Supports original format compatibility:
```
password1    123
password2    45
```
(Password + Tab + Success Count)

## Settings

- **Performance**: Adjust concurrent threads (1-8)
- **Detection**: Toggle steganography, encoding fixes, self-extract detection
- **Recursion**: Configure max nesting depth (1-20)
- **Cleanup**: Auto-move successful archives to Trash
- **Encoding**: Auto-fix garbled filenames (SHIFT-JIS, GB2312, etc.)

## Architecture

- **Rust-like Safety**: Swift with proper error handling
- **No Silent Fallbacks**: Errors are reported clearly
- **Content-Based Detection**: Actual file inspection, not extension-based
- **Modular Design**: Separate concerns for UI, engine, and file operations

## UI Design

- **MeshGradient Background**: Dynamic color gradients
- **Frosted Glass Effects**: Native macOS 26 `.glassEffect()`
- **Smooth Animations**: Spring physics for natural motion
- **Numeric Transitions**: Animated counter updates
- **Symbol Effects**: Bounce and replace animations

## Keyboard Shortcuts

- `Cmd+Q`: Quit
- `Cmd+F`: Show floating password input
- `Return`: Submit password in floating input

## Performance Tips

- Use **Smart Sorting** for faster password matching
- Enable **Dynamic Extraction** to start processing immediately
- Adjust **Concurrent Threads** based on your CPU (4-8 recommended)
- Enable **Encoding Fix** for archives with non-ASCII filenames

## Troubleshooting

**7-Zip not found?**
```bash
brew install p7zip
```

**Archives not recognized?**
- Check file integrity
- Try manual password entry
- Enable "Force Steganography Detection" for hidden archives

**Garbled filenames?**
- Enable "Fix Encoding" in settings
- Supports SHIFT-JIS (Japanese), GB2312 (Chinese), UTF-8

## Credits

- Original inspiration: ErsVId's "解TM的压" (UnzipTM)
- 7-Zip project
- macOS SwiftUI framework

## License

MIT

---

## 中文

> 一个原生 macOS 解压工具，支持智能密码字典自动尝试。灵感来自 Windows 工具「解TM的压」。

## 功能

- **4层密码队列**: 字符匹配 → 缓存 → 单次 → 永久
- **智能排序**: 成功次数多的密码优先
- **隐写包检测**: 检测图片/视频中的隐藏压缩包
- **分卷压缩包**: 自动识别并跳过非首包
- **递归解压**: 自动解压嵌套压缩包
- **乱码修复**: 自动修复日文/中文乱码文件名
- **动态解压**: 搜索完一个目录立即开始解压
- **悬浮密码框**: 随时添加密码
- **原生液态玻璃UI**: macOS 26 Tahoe 风格，MeshGradient 动态背景
- **并发处理**: 可配置并行解压线程 (1-8)
- **支持格式**: ZIP、RAR、7Z、TAR、GZ、BZ2、XZ、TGZ、EXE (自解压)

## 要求

- macOS 26.0+
- 7-Zip: `brew install p7zip`

## 安装

```bash
git clone https://github.com/nowaytouse/UnzipDict.git
cd UnzipDict
swift build -c release
open .build/release/UnzipDict
```

## 使用

1. **拖放**: 将压缩文件或文件夹拖到窗口
2. **开始**: 点击「开始解压」按钮
3. **悬浮框**: 通过菜单栏图标显示悬浮密码输入框
4. **监控**: 在「任务」「密码」「日志」标签页查看进度

## 密码管理

### 4层队列策略

密码按以下顺序尝试：

1. **字符匹配** (最高优先级)
   - 空密码
   - 文件名作为密码
   - 括号内容: `archive(password).zip` → 尝试 "password"

2. **缓存密码** (最近成功)
   - 最后 20 个成功的密码
   - 自动填充

3. **单次密码**
   - 使用后标记删除
   - 适合临时密码

4. **永久密码** (最低优先级)
   - 按成功次数排序
   - 可导入/导出

### 导入/导出

支持原作者格式兼容：
```
密码1    123
密码2    45
```
(密码 + Tab + 成功次数)

## 设置

- **性能**: 调整并发线程数 (1-8)
- **检测**: 隐写包、编码修复、自解压检测
- **递归**: 配置最大嵌套层数 (1-20)
- **清理**: 成功后自动移到回收站
- **编码**: 自动修复乱码文件名 (SHIFT-JIS、GB2312 等)

## 架构

- **安全设计**: Swift 的类型安全和错误处理
- **无静默失败**: 错误清晰报告
- **内容检测**: 基于实际文件检查，不依赖扩展名
- **模块化**: UI、引擎、文件操作分离

## UI 设计

- **MeshGradient 背景**: 动态色彩渐变
- **液态玻璃效果**: 原生 macOS 26 `.glassEffect()`
- **流畅动画**: 弹簧物理动画
- **数字过渡**: 计数器动画更新
- **符号动画**: 弹跳和替换效果

## 快捷键

- `Cmd+Q`: 退出
- `Cmd+F`: 显示悬浮密码输入框
- `Return`: 提交悬浮框中的密码

## 性能建议

- 启用**智能排序**加快密码匹配
- 启用**动态解压**立即开始处理
- 根据 CPU 调整**并发线程** (推荐 4-8)
- 对非 ASCII 文件名启用**编码修复**

## 故障排除

**找不到 7-Zip?**
```bash
brew install p7zip
```

**压缩包无法识别?**
- 检查文件完整性
- 尝试手动输入密码
- 启用「强制隐写检测」查找隐藏压缩包

**文件名乱码?**
- 在设置中启用「修复乱码文件名」
- 支持 SHIFT-JIS (日文)、GB2312 (中文)、UTF-8

## 致谢

- 原作者 ErsVId 的「解TM的压」工具
- 7-Zip 项目
- macOS SwiftUI 框架

## 许可证

MIT
