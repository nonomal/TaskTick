import SwiftUI
import TaskTickCore

/// Settings → Command Line → Raycast section. Points users at the official
/// Raycast extension, which drives TaskTick through the `tasktick` CLI.
struct RaycastExtensionSection: View {

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("settings.raycast.description"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Link(L10n.tr("settings.raycast.link"),
                     destination: URL(string: "https://www.raycast.com/lifedever/tasktick")!)
                    .font(.callout)
            }
            .padding(.vertical, 4)
        } header: {
            Text(L10n.tr("settings.raycast.section.title"))
        }
    }
}
