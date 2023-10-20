import Foundation
import SwiftUI

struct IntroView: View {
    var onDone: () -> Void  // Declare a callback function
    
    @State private var selectedPage = 0  // Track the selected page
    
    var body: some View {
        TabView(selection: $selectedPage) {
            
            // Page 1: Privacy Agreement
            VStack {
                Spacer()
                
                Text("By pressing Accept, you agree on following voice recognition pipeline:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("\n1. App records your voice\n2. Sends it to our server\n3. Our server redirects your voice to OpenAI Whisper API\n4. Our server send the recognised text back to you\n5. Right after the recognition we remove your voice from our server. ")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Though we have access to your voice recording on our server during the recognition, we promise not to listen to it.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Link("Also you can check OpenAI API privacy policy", destination: URL(string: "https://openai.com/policies/privacy-policy")!)
                    .padding()
                
                Button(action: { selectedPage = 1 }) {  // Navigate to Page 2 on button tap
                    Text("Accept")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .tag(0)
            
            // Page 2: Enabling Keyboard
            VStack {
                Spacer()
                
                Text("How to enable Whis-Key-Board:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Link("1. Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("2. Tap Keyboards")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("3. Enable whis-key-board")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: { selectedPage = 2 }) {
                    Text("Done")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .tag(1)
            
            // Page 3: Subscription
            VStack {
                
                Text("You need to subscribe to use WhisKeyBoard:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: {}) {
                    Text("Subscribe for 5$/month")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .tag(2)
            
        }
    }
}
