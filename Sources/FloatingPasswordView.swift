import SwiftUI

struct FloatingPasswordView: View {
    @EnvironmentObject var engine: UnzipEngine
    @State private var password = ""
    @State private var isExpanded = false
    @State private var showSuccess = false
    @State private var isOneTime = false
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 主输入区
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)

                TextField("输入密码...", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addPassword() }

                Button(action: { isOneTime.toggle() }) {
                    Image(systemName: isOneTime ? "flame.fill" : "flame")
                        .foregroundColor(isOneTime ? .orange : .secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(isOneTime ? "单次密码" : "永久密码")

                Button(action: addPassword) {
                    Image(systemName: showSuccess ? "checkmark.circle.fill" : "plus.circle.fill")
                        .foregroundColor(showSuccess ? .green : (password.isEmpty ? .secondary : .blue))
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .disabled(password.isEmpty)

                Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: { onClose?() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 10)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(engine.passwords.prefix(12)) { entry in
                            Button(action: { password = entry.password }) {
                                HStack {
                                    Text(entry.password)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if entry.successCount > 0 {
                                        Text("\(entry.successCount)")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 160)
            }
        }
        .frame(width: 300)
        .glassEffect(.regular.interactive())
    }

    private func addPassword() {
        guard !password.isEmpty else { return }
        engine.addPassword(password, isOneTime: isOneTime)
        withAnimation(.spring(response: 0.2)) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation {
                showSuccess = false
                password = ""
            }
        }
    }
}
