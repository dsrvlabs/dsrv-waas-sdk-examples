import SwiftUI
import dsrv_wallet_sdk_ios

struct RestoreSection: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        SectionCard("복원", subtitle: "iCloud Keychain 에 보관된 share 자동 복원") {
            Text("iCloud Keychain 에 보관된 share 를 일괄 복원. 기기 인증이 필요할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                wallet.restore()
            } label: {
                buttonLabel("복원", loading: wallet.uiState.restoreLoading, style: .filled)
            }
            .disabled(!wallet.uiState.sdkInitialized || wallet.uiState.restoreLoading)

            if let result = wallet.uiState.restoreResult {
                Text("✓ \(result)").font(.footnote)
            }
            // address 별 복원 결과를 화면에 직접 표시 (성공 / 실패)
            if !wallet.uiState.restoreResults.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(wallet.uiState.restoreResults, id: \.address) { r in
                        let short = r.address.count >= 12 ? String(r.address.prefix(12)) + "…" : r.address
                        if r.success {
                            Text("✓ \(short)  복원 완료")
                                .font(.footnote)
                                .foregroundColor(.accentColor)
                        } else {
                            Text("⛔ \(short)  복원 실패\(r.error.map { " — \($0)" } ?? "")")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let err = wallet.uiState.restoreError {
                ErrorLine(message: err)
            }
        }
    }
}
