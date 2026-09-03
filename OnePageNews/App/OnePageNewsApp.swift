import SwiftUI

@main
struct OnePageNewsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environment(model)
                .textSizeFloor(model.preferences.textSize)
                .onAppear { DailyNotification.apply(model.preferences, muted: FocusMute.isMuted) }
        }
    }
}

/// The reader's text size choice is a floor, never a ceiling. If the system
/// size is already bigger, the system wins.
struct TextSizeFloor: ViewModifier {
    let size: TextSize

    func body(content: Content) -> some View {
        switch size {
        case .system: content
        case .large: content.dynamicTypeSize(DynamicTypeSize.large...)
        case .larger: content.dynamicTypeSize(DynamicTypeSize.xLarge...)
        case .largest: content.dynamicTypeSize(DynamicTypeSize.xxxLarge...)
        }
    }
}

extension View {
    func textSizeFloor(_ size: TextSize) -> some View {
        modifier(TextSizeFloor(size: size))
    }
}
