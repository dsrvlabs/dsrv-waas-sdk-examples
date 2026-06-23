import SwiftUI
import dsrv_wallet_sdk_ios

/// Setup status (읽기 전용) — 선택 지갑의 chain 별 위임(EIP-7702)·승인(Permit2) 상태.
/// 화면 진입·선택 지갑 변경 시 자동 갱신되며, approve/revoke/delegate 직후에도 갱신된다.
/// "새로고침" 버튼으로 수동 갱신도 가능하다.
struct SetupStatusSection: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        let state = wallet.uiState
        SectionCard(
            "Setup status",
            subtitle: "chain 별 위임 · 승인 상태 (읽기 전용)",
            trailing: {
                if state.setupStatusLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button("새로고침") { wallet.getSetupStatus() }
                        .disabled(!state.sdkInitialized || wallet.address.isEmpty)
                        .font(.footnote)
                }
            }
        ) {
            if state.setupStatus.isEmpty {
                Text(state.setupStatusLoading ? "불러오는 중…" : "상태 없음 — [새로고침] 으로 확인")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(state.setupStatus.enumerated()), id: \.offset) { idx, chain in
                    chainRow(chain)
                    if idx < state.setupStatus.count - 1 { Divider() }
                }
            }
            if let err = state.setupStatusError {
                ErrorLine(message: err)
            }
        }
        .onAppear { autoLoad() }
        .onChange(of: wallet.address) { _ in autoLoad() }
    }

    /// 진입·선택 지갑 변경 시 자동 조회 — stale 한 이전 승인 내역이 남지 않도록.
    private func autoLoad() {
        guard wallet.uiState.sdkInitialized, !wallet.address.isEmpty else { return }
        wallet.getSetupStatus()
    }

    @ViewBuilder
    private func chainRow(_ chain: ChainSetupStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("chain \(chain.chainId)").font(.subheadline.bold())
                Spacer()
                badge(label: "위임", on: chain.delegated)
            }
            if chain.approvals.isEmpty {
                Text("승인된 token 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(chain.approvals.enumerated()), id: \.offset) { _, t in
                    tokenRow(t)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func tokenRow(_ t: TokenApproval) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("\(t.token.prefix(10))…\(t.token.suffix(6))")
                    .font(.caption.monospaced())
                Spacer()
                badge(label: "approve", on: t.approved)
            }
            Text("amount=\(t.amount)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text("expiration=\(t.expiration)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text("erc20Allowance=\(t.erc20Allowance)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 8)
        .padding(.vertical, 2)
    }

    private func badge(label: String, on: Bool) -> some View {
        Text("\(on ? "✓" : "✗") \(label)")
            .font(.caption2)
            .foregroundColor(on ? .green : .secondary)
    }
}
