import SwiftUI
import dsrv_wallet_sdk_ios

/// Approve UI — 지원 chain 전체 × project_assets 의 활성 ERC-20 을 한 번에 approve.
/// client 는 chain / token 을 명시하지 않는다 — WaaS 가 자동 결정.
///
/// amount 는 자유 입력 — 비우면 SDK 가 "MAX" 로 처리. "0" 입력 시 Permit2 권한만 revoke.
struct ApproveSection: View {
    @EnvironmentObject var wallet: Wallet
    @State private var amount: String = ""

    var body: some View {
        SectionCard(
            "Approve",
            subtitle: "결제 컨트랙트 multicall approve — 모든 chain × 등록 token 일괄"
        ) {
            Text("WaaS 의 project_assets 에 등록된 활성 ERC-20 을 지원 chain 전체에 일괄 approve 합니다. 비워두면 MAX (unbounded). \"0\" 입력 시 Permit2 권한 해제.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("amount (기본 MAX)", text: $amount)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            Button {
                wallet.approve(amountInput: amount)
            } label: {
                buttonLabel("Approve", loading: wallet.uiState.approveLoading, style: .filled)
            }
            .disabled(!wallet.uiState.sdkInitialized
                      || wallet.publicKey.isEmpty
                      || wallet.uiState.approveLoading)

            if !wallet.uiState.approveResults.isEmpty {
                let results = wallet.uiState.approveResults
                let successes = results.filter { $0.isSuccess }.count
                let failures = results.count - successes
                Text("결과: success=\(successes) / failed=\(failures) (총 \(results.count) chains)")
                    .font(.footnote)
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                    if !item.isSuccess {
                        Text("✗ \(item.chainId) [\(item.outcome)]: \(item.errorMessage ?? "unknown")")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let h = item.txHash {
                        Text("✓ \(item.chainId) [\(item.outcome)]").font(.footnote)
                        CopyableText(text: h, singleLine: true)
                    } else {
                        // SKIPPED — txHash 없음
                        Text("✓ \(item.chainId) [\(item.outcome)]").font(.footnote)
                    }
                }
            }
            if let err = wallet.uiState.approveError {
                ErrorLine(message: err)
            }
        }
    }
}
