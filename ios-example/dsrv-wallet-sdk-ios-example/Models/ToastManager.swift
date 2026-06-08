import SwiftUI
import Combine

final class ToastManager: ObservableObject {
    @Published var message: String? = nil

    func show(_ text: String, duration: TimeInterval = 1.2) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.message = nil
        }
    }
}
