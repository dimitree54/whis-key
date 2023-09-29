import SwiftUI

@main
struct MyApp: App {
    @State private var smartMode: Bool = false
    @State private var fromKeyboard: Bool = false
    var body: some Scene {
        WindowGroup {
            VoiceRecognitionView(smartMode: $smartMode, fromKeyboard: $fromKeyboard)
                .onOpenURL { url in
                    // Parse the URL to get the parameter value
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    let smartModeText = components?.queryItems?.first(where: { $0.name == "smartMode" })?.value
                    smartMode = smartModeText == "true"
                    fromKeyboard = true
                }
        }
    }
}
