import SwiftUI

@main
struct dsrv_wallet_sdk_ios_exampleApp: App {
    @StateObject private var wallet = Wallet()
    @StateObject private var toast = ToastManager()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(wallet)
                .environmentObject(toast)
        }
    }
}
