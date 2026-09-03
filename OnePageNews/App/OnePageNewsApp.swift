import SwiftUI

@main
struct OnePageNewsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            BriefingView()
                .environment(model)
        }
    }
}
