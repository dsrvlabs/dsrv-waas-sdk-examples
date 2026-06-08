import SwiftUI

/// 거래 내역 조회 — customer-backend `GET /sdk/transactions` (선택 지갑 fromAddress 기준).
struct HistorySection: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        SectionCard(
            "거래 내역",
            subtitle: "총 \(wallet.uiState.historyTotal)건 · 지갑 \(shortHex(wallet.address))"
        ) {
            HStack {
                Spacer()
                if wallet.uiState.historyLoading {
                    ProgressView().controlSize(.small)
                }
                Button("새로고침") {
                    wallet.getTransactionHistory()
                }
                .font(.subheadline)
                .disabled(!wallet.uiState.sdkInitialized || wallet.uiState.historyLoading)
            }

            if let err = wallet.uiState.historyError {
                ErrorLine(message: err)
            }

            if wallet.uiState.historyItems.isEmpty
                && !wallet.uiState.historyLoading
                && wallet.uiState.historyError == nil {
                Text("거래 내역이 없습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(wallet.uiState.historyItems) { item in
                HistoryItemCard(item: item)
            }

            if wallet.uiState.historyItems.count < wallet.uiState.historyTotal {
                Button {
                    wallet.getTransactionHistory(loadMore: true)
                } label: {
                    buttonLabel(
                        "더 보기 (\(wallet.uiState.historyItems.count)/\(wallet.uiState.historyTotal))",
                        loading: wallet.uiState.historyLoading,
                        style: .outlined
                    )
                }
                .disabled(wallet.uiState.historyLoading)
            }
        }
        .onAppear {
            // 진입 시 자동 조회
            if !wallet.address.isEmpty {
                wallet.getTransactionHistory()
            }
        }
    }
}

private struct HistoryItemCard: View {
    @EnvironmentObject var toast: ToastManager
    let item: TransactionHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.method ?? "transaction")
                        .font(.subheadline.bold())
                    Text(item.createdAt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Divider().padding(.vertical, 2)

            KeyValueRow(label: "체인", value: "\(item.chainId) (\(item.chainType))")
            KeyValueRow(label: "보낸 주소", value: shortHex(item.fromAddress))
            if let to = item.toAddress {
                KeyValueRow(label: "받는 주소", value: shortHex(to))
            }
            KeyValueRow(label: "txId", value: item.transactionId)
            if let hash = item.txHash {
                Button {
                    UIPasteboard.general.string = hash
                    toast.show("txHash 복사됨")
                } label: {
                    KeyValueRow(label: "txHash", value: hash)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private func shortHex(_ s: String) -> String {
    s.count <= 16 ? s : "\(s.prefix(10))…\(s.suffix(4))"
}
