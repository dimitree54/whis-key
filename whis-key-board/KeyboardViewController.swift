import KeyboardKit
import SwiftUI

struct MyCustomToolbar: View {
    unowned var controller: KeyboardInputViewController
    @State private var isSmartModeOn: Bool = UserDefaults.standard.bool(forKey: "smartMode")
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        HStack{
            if horizontalSizeClass == .regular {
                inputSourceButton
            }
            toolbar
        }
    }
    
    var toolbar: some View {
        HStack {
            Spacer()
            microphoneButton
            Spacer()
            toggleAndViewButtons
            Spacer()
            actionButtons
        }
        .onAppear(perform: fetchRecognizedText)
    }
    
    var microphoneButton: some View {
        Button(action: startDictation) {
            Image(systemName: "mic.fill")
                .foregroundColor(.white)
                .font(.system(size: 60))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
    
    var toggleAndViewButtons: some View {
        VStack{
            Spacer()
            Toggle("", isOn: $isSmartModeOn)
                .labelsHidden()
                .onChange(of: isSmartModeOn) {
                    UserDefaults.standard.set(isSmartModeOn, forKey: "smartMode")
                }
            Text("Smart mode")
            Spacer()
            Button(action: {controller.keyboardActionHandler.handle(.character(" "))}){
                Text("space            ")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray)
                    .cornerRadius(10)
            }
            .buttonRepeatBehavior(.enabled)
            .padding()
        }
    }
    
    var inputSourceButton: some View {
        VStack{
            Spacer()
            buttonWithIcon(action: {controller.advanceToNextInputMode()}, systemName: "globe")
        }
        .padding()
    }
    
    var actionButtons: some View {
        VStack{
            buttonWithIcon(action: {controller.keyboardActionHandler.handle(.backspace)}, systemName: "delete.left.fill")
                .buttonRepeatBehavior(.enabled)
            buttonWithIcon(action: {controller.keyboardActionHandler.handle(.character("\n"))}, systemName: "return")
            buttonWithIcon(action: {controller.keyboardActionHandler.handle(.dismissKeyboard)}, systemName: "keyboard.chevron.compact.down")
        }
        .padding()
    }
    
    func buttonWithIcon(action: @escaping () -> Void, systemName: String) -> some View {
        Button(action: action){
            Image(systemName: systemName)
                .foregroundColor(.white)
                .padding()
                .background(Color.gray)
                .cornerRadius(10)
        }
    }
    
    func startDictation() {
        UserDefaults.standard.set(true, forKey: "waitingForText")
        let smartModeText = isSmartModeOn ? "true" : "false"
        if let url = URL(string: "whiskeyschema://dictation?smartMode=\(smartModeText)") {
            controller.openUrl(url)
        }
    }
    
    func fetchRecognizedText() {
        guard UserDefaults.standard.bool(forKey: "waitingForText") else { return }
        
        let sharedDefaults = UserDefaults(suiteName: "group.we.rashchenko")
        if let recognizedText = sharedDefaults?.string(forKey: "recognizedText") {
            controller.textDocumentProxy.insertText(recognizedText)
            UserDefaults.standard.set(false, forKey: "waitingForText")
        }
    }
}

class KeyboardViewController: KeyboardInputViewController {
    override func viewWillSetupKeyboard() {
        super.viewWillSetupKeyboard()
        setup { controller in
            MyCustomToolbar(controller: controller)
        }
    }
}
