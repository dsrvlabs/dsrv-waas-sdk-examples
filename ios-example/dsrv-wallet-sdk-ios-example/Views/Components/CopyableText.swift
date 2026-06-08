import SwiftUI

struct CopyableText: View {
    @EnvironmentObject var toast: ToastManager

    let text: String
    var singleLine: Bool = false
    var fullText: String? = nil

    var body: some View {
        let textToCopy = fullText ?? text
        HStack(alignment: .center, spacing: 8) {
            Text(text)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(singleLine ? 1 : nil)
                .truncationMode(singleLine ? .middle : .tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !textToCopy.isEmpty {
                Button {
                    UIPasteboard.general.string = textToCopy
                    toast.show("Copied!")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.footnote)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

