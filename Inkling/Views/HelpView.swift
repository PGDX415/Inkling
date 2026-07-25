import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // AI Polish (highlighted, most important)
                featuredSection(
                    icon: "sparkles",
                    title: "help.ai_title",
                    body: "help.ai_body"
                )

                Divider()

                helpItem(icon: "square.and.pencil", title: "help.write_title", body: "help.write_body")
                helpItem(icon: "calendar", title: "help.calendar_title", body: "help.calendar_body")
                helpItem(icon: "photo", title: "help.photo_title", body: "help.photo_body")
                helpItem(icon: "textformat.size", title: "help.font_title", body: "help.font_body")
                helpItem(icon: "lock.shield", title: "help.lock_title", body: "help.lock_body")
                helpItem(icon: "icloud", title: "help.sync_title", body: "help.sync_body")
                helpItem(icon: "square.and.arrow.up", title: "help.export_title", body: "help.export_body")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color("JournalBackground"))
        .navigationTitle("help.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func featuredSection(icon: String, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.brown)
                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
            }

            Text(body)
                .font(.body)
                .lineSpacing(8)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brown.opacity(0.06))
                )
        }
    }

    private func helpItem(icon: String, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.brown)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
}
