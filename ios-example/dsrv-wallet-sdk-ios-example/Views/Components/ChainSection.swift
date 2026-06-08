import SwiftUI
import dsrv_wallet_sdk_ios

struct ChainSection: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        SectionCard("체인", subtitle: "지원 체인 · 활성 선택") {
            HStack {
                Text("목록 (\(wallet.uiState.chains.count))")
                    .font(.subheadline.bold())
                Spacer()
                if wallet.uiState.chainsLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button("조회") { wallet.getChainList() }
                        .disabled(!wallet.uiState.sdkInitialized)
                        .font(.footnote)
                }
            }

            if wallet.uiState.chains.isEmpty {
                Text(wallet.uiState.chainsLoading ? "불러오는 중…" : "(없음)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(wallet.uiState.chains.enumerated()), id: \.offset) { idx, chain in
                    Button {
                        wallet.selectChain(chain.chainId)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: wallet.uiState.selectedChainId == chain.chainId
                                  ? "largecircle.fill.circle"
                                  : "circle")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chain.name)
                                    .font(.subheadline)
                                Text("\(chain.chainType)·\(chain.networkType)·\(chain.chainId)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    if idx < wallet.uiState.chains.count - 1 { Divider() }
                }
            }

            if let err = wallet.uiState.chainsError {
                ErrorLine(message: err)
            }
        }
    }
}
