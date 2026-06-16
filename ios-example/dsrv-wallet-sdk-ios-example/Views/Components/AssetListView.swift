import SwiftUI
import dsrv_wallet_sdk_ios

/// 보유 자산 '전체'를 리스트로 펼쳐 조회 — 선택 체인의 모든 자산을 한 번에 표시(자산별 잔액 + KRW).
///
/// 자산 목록/로딩/에러는 `Wallet.uiState`(공용)에서 관찰하고(`wallet.loadAssets()`가 적재),
/// 자산별 KRW 맵만 View 가 보관한다. 전송 드롭다운(`AssetBalanceView`, 단일 선택)과 달리 전 자산을 펼친다.
struct AssetListView: View {
    @EnvironmentObject var wallet: Wallet

    /// 자산별 KRW 환산 문자열 (AssetRow.id → "₩...").
    @State private var krwById: [String: String] = [:]
    @State private var krwGeneration = 0

    private var assets: [AssetRow] { wallet.uiState.assets }
    private var chain: ChainInfo? {
        wallet.uiState.chains.first { $0.chainId == wallet.uiState.selectedChainId }
    }

    var body: some View {
        SectionCard("보유 자산", subtitle: "체인 \(chain?.name ?? (wallet.uiState.selectedChainId ?? "없음"))") {
            if wallet.uiState.assetsLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("자산 조회 중…").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let err = wallet.uiState.assetsError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(err).font(.caption).foregroundColor(.red)
                    Button("다시 시도") { Task { await wallet.loadAssets() } }.font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if assets.isEmpty {
                Text("보유 자산이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(assets.enumerated()), id: \.element.id) { idx, row in
                    assetRow(row)
                    if idx < assets.count - 1 { Divider() }
                }
            }

            HStack {
                Spacer()
                Button("새로고침") { Task { await wallet.loadAssets() } }
                    .font(.footnote)
                    .disabled(wallet.uiState.assetsLoading)
            }
        }
        .onAppear { Task { await wallet.loadAssets() } }
        .onChange(of: wallet.address) { _ in Task { await wallet.loadAssets() } }
        .onChange(of: wallet.uiState.selectedAccountId) { _ in Task { await wallet.loadAssets() } }
        .onChange(of: wallet.uiState.selectedChainId) { _ in Task { await wallet.loadAssets() } }
        // 공용 목록 갱신 시 자산별 KRW 재조회.
        .onChange(of: wallet.uiState.assets) { _ in Task { await loadKrw() } }
    }

    private func assetRow(_ row: AssetRow) -> some View {
        HStack(alignment: .center) {
            Text(row.symbol).font(.subheadline.weight(.semibold))
            Spacer()
            // 잔액(위) + KRW(아래) 우측 정렬.
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.humanizedBalance)
                    .font(.subheadline)
                    .monospacedDigit()
                if let krw = krwById[row.id] {
                    Text(krw).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// 현재 공용 목록(uiState.assets)의 각 자산 KRW 환산. 자산별로 채워진다.
    private func loadKrw() async {
        krwGeneration += 1
        let gen = krwGeneration
        krwById = [:]
        for row in assets {
            let krw = await wallet.getKrwValue(
                chainId: row.chainId,
                contractAddress: row.contractAddress,
                amount: row.humanizedBalance
            )
            guard gen == krwGeneration else { return }
            if let krw { krwById[row.id] = krw }
        }
    }
}
