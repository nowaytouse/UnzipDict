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
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.quaternary)
                    .font(.system(size: 10))

                TextField("输入密码...", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { addPassword() }

                Button { isOneTime.toggle() } label: {
                    Image(systemName: isOneTime ? "flame.fill" : "flame")
                        .font(.system(size: 10))
                        .foregroundStyle(isOneTime ? .orange : .tertiary)
                }
                .buttonStyle(.plain)
                .help(isOneTime ? "单次密码" : "永久密码")

                Button(action: addPassword) {
                    Image(systemName: showSuccess ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(showSuccess ? .green : (password.isEmpty ? .tertiary : .blue))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(password.isEmpty)

                Button { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .buttonStyle(.plain)

                Button { onClose?() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if isExpanded {
                Divider().padding(.horizontal, 8)

                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(engine.passwords.prefix(10)) { entry in
                            Button { password = entry.password } label: {
                                HStack {
                                    Text(entry.password)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if entry.successCount > 0 {
                                        Text("\(entry.successCount)")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 140)
            }
        }
        .frame(width: 280)
        .glassEffect(.regular.interactive())
    }

    private func addPassword() {
        guard !password.isEmpty else { return }
        engine.addPassword(password, isOneTime: isOneTime)
        withAnimation(.spring(response: 0.2)) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation {
                showSuccess = false
                password = ""
            }
        }
    }
}
