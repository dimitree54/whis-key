import KeyboardKit
import SwiftUI

struct MyCustomToolbar: View {
    unowned var controller: KeyboardInputViewController
    @State private var isSmartModeOn: Bool = false

    var body: some View {
        HStack {
            Spacer()
            
            Button(action: startDictation) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 60))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Take all available space
            .background(Color.blue)
            .clipShape(Circle())
            .padding()
            
            Spacer()
            
            VStack{
                Spacer()
                Toggle("", isOn: $isSmartModeOn)
                    .labelsHidden()
                    .onChange(of: isSmartModeOn) {
                        saveSmartMode()
                    }
                Text("Smart mode")
                Spacer()
                Button(action: {}){
                    Text("space            ")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(10)
                }
                .padding()
            }
            
            Spacer()
            
            VStack{
                Button(action: {controller.keyboardActionHandler.handle(.backspace)}){
                    Image(systemName: "delete.left.fill") // Use a system symbol for the microphone
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(10)
                }
                Button(action: {controller.keyboardActionHandler.handle(.character("\n"))}){
                    Image(systemName: "return") // Use a system symbol for the microphone
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(10)
                }
                Button(action: {controller.keyboardActionHandler.handle(.dismissKeyboard)}){
                    Image(systemName: "keyboard.chevron.compact.down") // Use a system symbol for the microphone
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .onAppear(perform: fetchRecognizedText)
        .onAppear(perform: loadSmartMode)
    }
    
    func createCustomButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Custom", for: .normal)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.layer.cornerRadius = 5
        return button
    }
    
    func startDictation(){
        UserDefaults.standard.set("true", forKey: "waitingForText")
        // Action for microphone button
        let smartModeText = isSmartModeOn ? "true" : "false"
        if let url = URL(string: "whiskeyschema://dictation?smartMode=\(smartModeText)") {
            controller.openUrl(url)
        }
    }
    
    func fetchRecognizedText() {
        let waitingForText = UserDefaults.standard.string(forKey: "waitingForText")
        if (waitingForText == "true"){
            let sharedDefaults = UserDefaults(suiteName: "group.we.rashchenko")
            let recognizedText = sharedDefaults?.string(forKey: "recognizedText")
            print(recognizedText)
            if let recognizedText = recognizedText {
                controller.textDocumentProxy.insertText(recognizedText)
                UserDefaults.standard.set("false", forKey: "waitingForText")
            }
        }
    }
    
    func saveSmartMode(){
        UserDefaults.standard.set(isSmartModeOn ? "true" : "false", forKey: "smartMode")
    }
    
    func loadSmartMode(){
        let smartModeText = UserDefaults.standard.string(forKey: "smartMode")
        isSmartModeOn = smartModeText == "true"
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
