import SwiftUI
import dsrv_wallet_sdk_ios

/// 자산 드롭다운 + 선택 자산 잔액 + KRW 환산 — 전송 화면에서 쓰는 공용 컴포넌트.
///
/// 자산 목록/로딩/에러는 `Wallet.uiState`(공용)에서 **관찰**하고, 화면별 상태(선택 자산·KRW)만
/// View 가 보관한다. 목록 적재는 `wallet.loadAssets()` 가 담당(ObservableObject). 선택된 자산은
/// `selectedAsset` 바인딩으로 부모(전송)에 전달한다(표시 전용이면 무시 — `.constant(nil)`).
struct AssetBalanceView: View {
    @EnvironmentObject var wallet: Wallet
    @Binding var selectedAsset: AssetRow?

    @State private var selectedAssetId: String? = nil
    @State private var krwValueText: String? = nil
    @State private var krwLoading = false
    @State private var krwGeneration = 0

    init(selectedAsset: Binding<AssetRow?> = .constant(nil)) {
        self._selectedAsset = selectedAsset
    }

    private var assets: [AssetRow] { wallet.uiState.assets }
    /// 저장된 선택 id 가 비었거나(첫 로드) 목록에 없으면 첫 자산으로 기본 선택 — Picker collapsed 라벨/
    /// 잔액/KRW 가 사용자 조작 없이도 즉시 첫 자산을 가리키게 한다(programmatic 선택 미반영 글리치 회피).
    private var effectiveSelectedId: String? {
        if let id = selectedAssetId, assets.contains(where: { $0.id == id }) { return id }
        return assets.first?.id
    }
    private var resolved: AssetRow? { assets.first(where: { $0.id == effectiveSelectedId }) }

    /// Picker 선택 시 즉시 KRW 갱신 + 부모에 선택 자산 전달.
    private var assetSelection: Binding<String?> {
        Binding(
            get: { effectiveSelectedId },
            set: { newValue in
                selectedAssetId = newValue
                selectedAsset = assets.first(where: { $0.id == newValue })
                Task { await refreshKrw() }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            assetPicker
            balanceRow
        }
        // 이미 목록이 로드된 채 진입하면 onChange(assets) 가 안 떠 선택/KRW 가 비므로 appear 시에도 보정.
        .onAppear { syncSelection(); Task { await wallet.loadAssets() } }
        .onChange(of: wallet.address) { _ in Task { await wallet.loadAssets() } }
        .onChange(of: wallet.uiState.selectedAccountId) { _ in Task { await wallet.loadAssets() } }
        .onChange(of: wallet.uiState.selectedChainId) { _ in Task { await wallet.loadAssets() } }
        // 공용 목록(uiState.assets) 갱신 시 선택 보정 + 부모 전달 + KRW 갱신.
        .onChange(of: wallet.uiState.assets) { _ in syncSelection() }
    }

    @ViewBuilder
    private var assetPicker: some View {
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
            Picker("자산", selection: assetSelection) {
                ForEach(assets) { asset in
                    Text(asset.displayLabel).tag(Optional(asset.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var balanceRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("현재 잔액").font(.caption).foregroundStyle(.secondary)
                if let asset = resolved {
                    Text("\(asset.humanizedBalance) \(asset.symbol)").font(.subheadline)
                } else {
                    Text("—").font(.footnote).foregroundStyle(.secondary)
                }
                if krwLoading {
                    Text("환산 중…").font(.caption).foregroundStyle(.secondary)
                } else if let krw = krwValueText {
                    Text(krw).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("새로고침") { Task { await wallet.loadAssets() } }
                .font(.footnote)
                .disabled(wallet.uiState.assetsLoading)
        }
    }

    /// 공용 목록이 갱신되면 선택 자산을 보정(없으면 첫 자산) → 부모 전달 → KRW 갱신.
    private func syncSelection() {
        if selectedAssetId == nil || !assets.contains(where: { $0.id == selectedAssetId }) {
            selectedAssetId = assets.first?.id
        }
        selectedAsset = resolved
        Task { await refreshKrw() }
    }

    /// 선택 자산의 잔액 → KRW 환산 (price-hub). 실패/미가용 시 nil.
    private func refreshKrw() async {
        krwGeneration += 1
        let gen = krwGeneration
        krwValueText = nil
        guard let asset = resolved else { krwLoading = false; return }
        krwLoading = true
        let krw = await wallet.getKrwValue(
            chainId: asset.chainId,
            contractAddress: asset.contractAddress,
            amount: asset.humanizedBalance
        )
        guard gen == krwGeneration else { return }
        krwValueText = krw
        krwLoading = false
    }
}
