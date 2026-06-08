import SwiftUI

struct RootView: View {
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        ZStack {
            WalletScreen()
        }
        .overlay(alignment: .top) {
            if let msg = toast.message {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut, value: toast.message)
    }
}
