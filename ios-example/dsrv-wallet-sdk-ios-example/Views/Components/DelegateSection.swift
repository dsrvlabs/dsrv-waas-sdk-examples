import SwiftUI
import dsrv_wallet_sdk_ios

struct DelegateSection: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        let state = wallet.uiState
        let alreadyDone = state.delegateAlreadyDone && state.delegateResults.isEmpty
        let delegateDone = alreadyDone || !state.delegateResults.isEmpty

        SectionCard("Delegate (EIP-7702)", subtitle: "지원 chain 일괄 broadcast") {
            Button {
                wallet.delegate()
            } label: {
                buttonLabel(
                    alreadyDone ? "다시 시도" : "Delegate",
                    loading: state.delegateLoading,
                    style: .filled
                )
            }
            .disabled(!state.sdkInitialized || wallet.address.isEmpty || state.delegateLoading)

            if alreadyDone {
                Text("✓ 이미 위임됨 — 추가 작업 불필요")
                    .font(.footnote)
            } else if !state.delegateResults.isEmpty {
                let successes = state.delegateResults.filter { $0.isSuccess }.count
                let failures = state.delegateResults.count - successes
                Text("결과: success=\(successes) / failed=\(failures) (총 \(state.delegateResults.count) chains)")
                    .font(.footnote.bold())
                ForEach(Array(state.delegateResults.enumerated()), id: \.offset) { _, item in
                    if !item.isSuccess {
                        Text("✗ \(item.chainId) [\(item.outcome)]: \(item.errorMessage ?? "unknown")")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let h = item.txHash {
                        Text("✓ \(item.chainId) [\(item.outcome)]").font(.footnote)
                        CopyableText(text: h, singleLine: true)
                    } else {
                        // ALREADY_DELEGATED — txHash 없음
                        Text("✓ \(item.chainId) [\(item.outcome)]").font(.footnote)
                    }
                }
            }
            if let err = state.delegateError {
                ErrorLine(message: err)
            }

            if delegateDone {
                Divider().padding(.vertical, 6)
                Text("위임 해제 (Revoke)").font(.subheadline.bold())
                Text("지원 chain 의 위임을 해제합니다. 해제 시 페이먼트의 Approve 도 사실상 무효화됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    wallet.revoke()
                } label: {
                    buttonLabel("Revoke", loading: state.delegateLoading, style: .destructive)
                }
                .disabled(!state.sdkInitialized || wallet.address.isEmpty || state.delegateLoading)
            }
        }
    }
}
