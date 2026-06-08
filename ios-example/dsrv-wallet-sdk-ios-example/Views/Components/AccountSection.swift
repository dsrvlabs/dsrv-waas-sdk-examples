import SwiftUI
import dsrv_wallet_sdk_ios

struct AccountSection: View {
    @EnvironmentObject var wallet: Wallet
    @State private var showCreateAccount = false
    @State private var addWalletAccountId: String? = nil

    var body: some View {
        SectionCard("계정 & 지갑", subtitle: "계정 생성·지갑 발급") {
            HStack(alignment: .center) {
                Text("계정 (\(wallet.uiState.accounts.count))")
                    .font(.subheadline.bold())
                Spacer()
                if wallet.uiState.accountsLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button("조회") { wallet.getAccountList() }
                        .disabled(!wallet.uiState.sdkInitialized)
                        .font(.footnote)
                }
                Button("+ 계정") { showCreateAccount = true }
                    .disabled(!wallet.uiState.sdkInitialized || wallet.uiState.createAccountLoading)
                    .font(.footnote)
            }

            if wallet.uiState.accounts.isEmpty {
                Text(wallet.uiState.accountsLoading ? "불러오는 중…" : "계정 없음 — [+ 계정] 으로 생성")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(wallet.uiState.accounts.enumerated()), id: \.offset) { idx, acc in
                    accountHeader(acc)
                    if acc.addresses.isEmpty {
                        Text("지갑 없음")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(acc.addresses.enumerated()), id: \.offset) { _, addr in
                            walletRow(
                                accountId: acc.accountId,
                                addr: addr,
                                selected: addr.address.lowercased() == wallet.address.lowercased()
                            )
                        }
                    }
                    if idx < wallet.uiState.accounts.count - 1 { Divider() }
                }
            }

            if let err = wallet.uiState.createAccountError ?? wallet.uiState.accountsError {
                ErrorLine(message: err)
            }
        }
        .sheet(isPresented: $showCreateAccount) {
            LabelDialog(
                title: "새 계정",
                description: "label 을 입력하세요 (비우면 자동 생성)",
                onConfirm: { label in
                    wallet.createAccount(label: label)
                    showCreateAccount = false
                },
                onDismiss: { showCreateAccount = false }
            )
        }
        .sheet(item: Binding(
            get: { addWalletAccountId.map { AccountIdWrapper(id: $0) } },
            set: { addWalletAccountId = $0?.id }
        )) { wrapper in
            LabelDialog(
                title: "새 지갑",
                description: "label 을 입력하세요 (비우면 자동 생성)",
                onConfirm: { label in
                    wallet.createAddress(accountIdInput: wrapper.id, labelInput: label)
                    addWalletAccountId = nil
                },
                onDismiss: { addWalletAccountId = nil }
            )
        }
    }

    private func accountHeader(_ acc: AccountInfo) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(acc.label).font(.subheadline.bold())
                Text("id \(shortId(acc.accountId)) · \(acc.addresses.count) wallets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("+ 지갑") { addWalletAccountId = acc.accountId }
                .font(.caption)
        }
        .padding(.vertical, 6)
    }

    private func walletRow(accountId: String, addr: AddressInfo, selected: Bool) -> some View {
        Button {
            wallet.selectAccount(accountId)
            wallet.selectWallet(addr.address)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(addr.address.prefix(10))…\(addr.address.suffix(6))")
                        .font(.subheadline.monospaced())
                    if let label = addr.label, !label.isEmpty {
                        Text(label).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.leading, 8)
        }
        .buttonStyle(.plain)
    }

    private func shortId(_ id: String) -> String {
        id.count <= 12 ? id : "\(id.prefix(8))…\(id.suffix(4))"
    }
}

private struct AccountIdWrapper: Identifiable {
    let id: String
}

private struct LabelDialog: View {
    let title: String
    let description: String
    let onConfirm: (String) -> Void
    let onDismiss: () -> Void

    @State private var label = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("label", text: $label)
                    .textFieldStyle(.roundedBorder)
                Spacer()
            }
            .padding(16)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("생성") { onConfirm(label) }
                }
            }
        }
    }
}
