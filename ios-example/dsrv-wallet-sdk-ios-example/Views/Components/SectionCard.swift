import SwiftUI

/// Android 의 SectionContainer 와 동일한 카드 컨테이너.
struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

/// label · value 한 행 (16 dp 좌우 spacing, label 82 dp 폭).
struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }
}

struct ErrorLine: View {
    let message: String
    var body: some View {
        Text("⚠ \(message)")
            .font(.caption)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoBanner: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}
