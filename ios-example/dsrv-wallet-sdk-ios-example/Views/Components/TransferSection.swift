import SwiftUI
import dsrv_wallet_sdk_ios

struct TransferSection: View {
    @EnvironmentObject var wallet: Wallet

    @State private var recipient: String = ""
    @State private var amount: String = ""
    @State private var scannerOpen = false
    @State private var confirmOpen = false

    // 자산 드롭다운 + 잔액 + KRW 는 공용 AssetBalanceView 가 담당. 여기선 선택된 자산만 받아 전송에 사용.
    @State private var selectedAsset: AssetRow? = nil

    private var chain: ChainInfo? {
        guard let asset = selectedAsset else { return nil }
        return wallet.uiState.chains.first(where: { $0.chainId == asset.chainId })
    }

    var body: some View {
        SectionCard("전송", subtitle: "체인 \(chain?.name ?? selectedAsset?.chainId ?? "없음") · \(selectedAsset?.symbol ?? "자산 없음")") {
            AssetBalanceView(selectedAsset: $selectedAsset)

            HStack(spacing: 8) {
                TextField("받는 주소", text: $recipient)
                    .textFieldStyle(.roundedBorder)
                Button("QR 스캔") { scannerOpen = true }
                    .font(.footnote)
            }

            TextField(amountPlaceholder, text: $amount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Button {
                // 빈 recipient / 자산 미선택 시 confirm 을 열지 않음 (disabled 와 중복되는 race 가드).
                let trimmed = recipient.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, selectedAsset != nil else { return }
                confirmOpen = true
            } label: {
                buttonLabel("거래 확인", loading: wallet.uiState.transferLoading, style: .filled)
            }
            .disabled(transferDisabled)

            // 전송 결과 — txHash (있을 때) + status + batchTxId (있을 때).
            // bundler 경로 (GS_ON) 에선 txHash 가 nil 이고 status="SIGNED" + batchTxId 가 채워짐.
            if wallet.uiState.lastTxHash != nil
                || wallet.uiState.lastTxStatus != nil
                || wallet.uiState.lastBatchTxId != nil {
                Text("✓ 전송 결과").font(.caption).foregroundColor(.green)
                if let hash = wallet.uiState.lastTxHash {
                    Text("TxHash").font(.caption2).foregroundStyle(.secondary)
                    CopyableText(text: hash, singleLine: true)
                }
                if let status = wallet.uiState.lastTxStatus {
                    Text("Status: \(status)").font(.caption)
                }
                if let batchTxId = wallet.uiState.lastBatchTxId {
                    Text("BatchTxId").font(.caption2).foregroundStyle(.secondary)
                    CopyableText(text: batchTxId, singleLine: true)
                }
            }
            if let err = wallet.uiState.transferError {
                ErrorLine(message: err)
            }
        }
        .sheet(isPresented: $scannerOpen) {
            QRScannerSheet(
                onScanned: { value in
                    recipient = parseRecipient(value)
                    scannerOpen = false
                },
                onClose: { scannerOpen = false }
            )
        }
        .alert("거래 확인", isPresented: $confirmOpen) {
            Button("취소", role: .cancel) { confirmOpen = false }
            Button("서명 & 전송") {
                confirmOpen = false
                guard let asset = selectedAsset else { return }
                wallet.transfer(
                    recipientInput: recipient,
                    amountInput: amount,
                    chainId: asset.chainId,
                    contractAddress: asset.contractAddress,
                    decimals: asset.decimals,
                    symbol: asset.symbol
                )
            }
        } message: {
            let sym = selectedAsset?.symbol ?? ""
            let isNative = selectedAsset?.isNative ?? true
            let effective = amount.trimmingCharacters(in: .whitespaces).isEmpty
                ? (isNative ? "0.001" : "1") : amount
            return Text("받는 사람: \(recipient)\n금액: \(effective) \(sym)\n체인: \(chain?.name ?? selectedAsset?.chainId ?? "?")\n\n⚠ 서명 후 되돌릴 수 없습니다.")
        }
    }

    private var amountPlaceholder: String {
        let sym = selectedAsset?.symbol ?? "토큰"
        let isNative = selectedAsset?.isNative ?? true
        return isNative ? "금액 (\(sym), 기본 0.001)" : "금액 (\(sym), 기본 1)"
    }

    private var transferDisabled: Bool {
        !wallet.uiState.sdkInitialized
            || wallet.uiState.transferLoading
            || recipient.trimmingCharacters(in: .whitespaces).isEmpty
            || selectedAsset == nil
    }
}

func parseRecipient(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    if trimmed.lowercased().hasPrefix("ethereum:") {
        let rest = String(trimmed.dropFirst("ethereum:".count))
        return rest.components(separatedBy: "@").first?
            .components(separatedBy: "/").first?
            .components(separatedBy: "?").first ?? rest
    }
    return trimmed
}

struct QRScannerSheet: View {
    let onScanned: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            QRScannerView(onScanned: onScanned, onClose: onClose)
                .ignoresSafeArea()
            Button("닫기", action: onClose)
                .padding(16)
                .foregroundColor(.white)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
