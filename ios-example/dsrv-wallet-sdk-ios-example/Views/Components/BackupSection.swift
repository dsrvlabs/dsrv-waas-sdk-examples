import SwiftUI

struct BackupSection: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        SectionCard("백업", subtitle: "iCloud Keychain 으로 키 share 보관") {
            Text("pending share 들을 iCloud Keychain 에 일괄 sync. 기기 인증이 필요할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                wallet.backup()
            } label: {
                buttonLabel(
                    "백업",
                    loading: wallet.uiState.backupLoading,
                    style: .filled
                )
            }
            .disabled(!wallet.uiState.sdkInitialized || wallet.uiState.backupLoading)

            if let result = wallet.uiState.backupResult {
                Text("✓ \(result)")
                    .font(.footnote)
            }
            if let err = wallet.uiState.backupError {
                ErrorLine(message: err)
            }

            Divider().padding(.top, 8)

            Text("디버그")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)

            Button {
                wallet.dumpKeychain()
            } label: {
                buttonLabel("Keychain dump", loading: false, style: .outlined)
            }
            .disabled(!wallet.uiState.sdkInitialized)

            Button {
                wallet.clearBackup()
            } label: {
                buttonLabel("Backup 전체 삭제", loading: false, style: .destructive)
            }
            .disabled(!wallet.uiState.sdkInitialized)

            if let dump = wallet.uiState.keychainDump {
                ScrollView {
                    Text(dump)
                        .font(.caption2.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 240)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
}

enum WalletButtonStyle { case filled, outlined, destructive }

struct WalletButtonLabel: View {
    let title: String
    let loading: Bool
    let style: WalletButtonStyle

    var body: some View {
        let (bg, fg, stroke): (Color, Color, Color?) = {
            switch style {
            case .filled: return (.accentColor, .white, nil)
            case .outlined: return (.clear, .accentColor, .accentColor)
            case .destructive: return (.clear, .red, .red)
            }
        }()
        HStack {
            if loading { ProgressView().tint(fg) }
            Text(title).font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .foregroundColor(fg)
        .background(RoundedRectangle(cornerRadius: 10).fill(bg))
        .overlay(
            Group {
                if let stroke {
                    RoundedRectangle(cornerRadius: 10).stroke(stroke, lineWidth: 1)
                }
            }
        )
    }
}

func buttonLabel(_ title: String, loading: Bool, style: WalletButtonStyle) -> some View {
    WalletButtonLabel(title: title, loading: loading, style: style)
}
