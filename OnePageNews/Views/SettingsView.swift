import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var preferences = model.preferences

        NavigationStack {
            Form {
                Section {
                    ForEach(Topic.allCases) { topic in
                        Toggle(isOn: topicBinding(topic)) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(topic.title)
                                    Text(topic.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: topic.symbol)
                                    .foregroundStyle(topic.color)
                            }
                        }
                        .disabled(topic.isRequired)
                    }
                } header: {
                    Text("Topics")
                } footer: {
                    Text("General news is always on. Pick anything else you want to stay on top of.")
                }

                Section {
                    Picker("Length", selection: $preferences.briefingLength) {
                        ForEach(BriefingLength.allCases) { length in
                            Text(length.title).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(preferences.briefingLength.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Briefing length")
                } footer: {
                    Text("Up to \(preferences.briefingLength.maxStories) stories on the page.")
                }

                Section {
                    TextField("https://your-server.example.com", text: $preferences.serverURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Data source")
                } footer: {
                    if preferences.serverURL == nil {
                        Text("Using the sample briefing bundled with the app. Enter a server URL to load live stories.")
                    } else {
                        Text("Loading from \(preferences.serverURL?.host() ?? "your server").")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Text("One page of what matters, with the facts first. Left and right views are there so you can see the framing; the unbiased view is the point.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func topicBinding(_ topic: Topic) -> Binding<Bool> {
        Binding(
            get: { topic.isRequired || model.preferences.selectedTopics.contains(topic) },
            set: { model.preferences.setTopic(topic, enabled: $0) }
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(preferences: Preferences(defaults: UserDefaults(suiteName: "preview")!)))
}
