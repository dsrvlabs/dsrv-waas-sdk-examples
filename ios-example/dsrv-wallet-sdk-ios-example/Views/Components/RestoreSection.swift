import SwiftUI

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
            if let err = wallet.uiState.restoreError {
                ErrorLine(message: err)
            }
        }
    }
}
