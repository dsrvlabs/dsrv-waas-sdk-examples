import SwiftUI

struct LogSection: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        SectionCard("로그", subtitle: "SDK · backend trace") {
            HStack {
                Text("\(wallet.uiState.logs.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { wallet.clearLogs() }
                    .font(.footnote)
                    .disabled(wallet.uiState.logs.isEmpty)
            }

            if wallet.uiState.logs.isEmpty {
                Text("(no logs)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(wallet.uiState.logs.enumerated()), id: \.offset) { idx, line in
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .foregroundColor(color(for: line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(idx)
                            }
                        }
                        .padding(8)
                    }
                    .frame(minHeight: 240)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .onChangeCompat(wallet.uiState.logs.count) { newCount in
                        if newCount > 0 {
                            withAnimation { proxy.scrollTo(newCount - 1, anchor: .bottom) }
                        }
                    }
                }
            }
        }
    }

    private func color(for line: String) -> Color {
        if line.contains("✗") { return .red }
        if line.contains("✓") { return .green }
        if line.contains("▶") { return .blue }
        return .primary
    }
}

private extension View {
    @ViewBuilder
    func onChangeCompat(_ value: Int, perform action: @escaping (Int) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value) { newValue in action(newValue) }
        }
    }
}
