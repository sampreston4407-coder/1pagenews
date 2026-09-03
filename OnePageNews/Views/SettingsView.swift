import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false

    var body: some View {
        @Bindable var prefs = model.preferences

        NavigationStack {
            Form {
                Section {
                    ForEach(Topic.optional) { topic in
                        Toggle(isOn: binding(for: topic)) {
                            Label(topic.title, systemImage: topic.symbol)
                        }
                    }
                } header: {
                    Text("Topics")
                } footer: {
                    Text("General news is always on. A topic adds a story or two after the seven. It never replaces them.")
                }

                Section {
                    Toggle("One a day", isOn: $prefs.notificationsOn)
                    if prefs.notificationsOn {
                        DatePicker("Time", selection: $prefs.notificationTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Notification")
                } footer: {
                    if permissionDenied {
                        Text("Notifications are off for this app in iOS Settings.")
                    } else {
                        Text("One notification a day at this time. Nothing else, ever.")
                    }
                }
                .onChange(of: prefs.notificationsOn) { _, on in
                    Task { await notificationsChanged(on: on) }
                }
                .onChange(of: prefs.notificationMinutes) { _, _ in
                    DailyNotification.apply(model.preferences, muted: FocusMute.isMuted)
                }

                Section("Text size") {
                    Picker("Text size", selection: $prefs.textSize) {
                        ForEach(TextSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("About") {
                    NavigationLink("Sources") { SourcesView() }
                    NavigationLink("How this works") { MethodologyView() }
                    NavigationLink("Corrections") { CorrectionsView() }
                    LabeledContent("Version", value: appVersion)
                }

                Section {
                    TextField("https://", text: $prefs.serverURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server")
                } footer: {
                    Text(prefs.serverURL == nil ? "No valid server URL. Showing the sample edition." : "Editions load from this server.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func notificationsChanged(on: Bool) async {
        if on {
            let granted = await DailyNotification.requestPermission()
            permissionDenied = !granted
            if !granted { model.preferences.notificationsOn = false }
        }
        DailyNotification.apply(model.preferences, muted: FocusMute.isMuted)
    }

    private func binding(for topic: Topic) -> Binding<Bool> {
        Binding(
            get: { model.preferences.isOn(topic) },
            set: { model.preferences.set(topic, on: $0) }
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

struct MethodologyView: View {
    @Environment(AppModel.self) private var model
    @State private var methodology: Methodology?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let methodology {
                    ForEach(methodology.sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.heading)
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Text(section.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    NavigationLink("See the corrections log") { CorrectionsView() }
                        .font(.subheadline)
                } else {
                    ProgressView()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(methodology?.title ?? "How this works")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let remote = try? await model.provider.fetchMethodology() {
                methodology = remote
            } else {
                methodology = try? await BundledEditionProvider().fetchMethodology()
            }
        }
    }
}

struct SourcesView: View {
    @Environment(AppModel.self) private var model
    @State private var sources: [SourceInfo] = []

    var body: some View {
        List {
            Section {
                ForEach(sources) { source in
                    Link(destination: source.homepage) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(source.outlet)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                LeanBadge(lean: source.lean)
                            }
                            Text(source.why)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } header: {
                Text("Where the stories come from")
                    .textCase(nil)
            } footer: {
                Text("We pull headlines and summaries, never full articles, from outlets across the spectrum. A line goes in 'not in dispute' only when every outlet reports it the same way. Lean ratings follow AllSides.")
            }
        }
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let remote = try? await model.provider.fetchSources() {
                sources = remote
            } else {
                sources = (try? await BundledEditionProvider().fetchSources()) ?? []
            }
        }
    }
}

struct CorrectionsView: View {
    @Environment(AppModel.self) private var model
    @State private var corrections: [Correction] = []
    @State private var loaded = false

    var body: some View {
        List {
            if loaded, corrections.isEmpty {
                ContentUnavailableView {
                    Label("No corrections yet", systemImage: "checkmark.circle")
                } description: {
                    Text("When we get something wrong, it goes here and stays here.")
                }
            }
            ForEach(corrections) { c in
                VStack(alignment: .leading, spacing: 6) {
                    Text(c.correctedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("We said: \(c.whatWeSaid)")
                    Text("True: \(c.whatWasTrue)")
                        .fontWeight(.semibold)
                    Text(c.howWeFoundOut)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("Corrections")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            corrections = (try? await model.provider.fetchCorrections()) ?? []
            loaded = true
        }
    }
}
