import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("privacy.title")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("privacy.intro")
                    .font(.body)
                    .lineSpacing(6)

                Divider()

                section(
                    title: "privacy.s1_title",
                    body: "privacy.s1_body"
                )

                section(
                    title: "privacy.s2_title",
                    body: "privacy.s2_body"
                )

                section(
                    title: "privacy.s3_title",
                    body: "privacy.s3_body"
                )

                section(
                    title: "privacy.s4_title",
                    body: "privacy.s4_body"
                )

                section(
                    title: "privacy.s5_title",
                    body: "privacy.s5_body"
                )

                section(
                    title: "privacy.s6_title",
                    body: "privacy.s6_body"
                )

                section(
                    title: "privacy.s7_title",
                    body: "privacy.s7_body"
                )

                Divider()

                Text("privacy.last_updated")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("2026-07-25")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color("JournalBackground"))
        .navigationTitle("privacy.nav_title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
            Text(body)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
