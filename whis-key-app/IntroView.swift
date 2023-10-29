import Foundation
import SwiftUI
import StoreKit

struct AgreementView: View {
    var onDone: () -> Void  // Declare a callback function
    var body: some View {
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
            
            Button(action: onDone) {  // Navigate to Page 2 on button tap
                Text("Accept")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct InstructionsView: View {
    var onDone: () -> Void  // Declare a callback function
    var body: some View {
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
            
            Button(action: onDone) {
                Text("Done")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct SubscriptionView: View {
    @State private var isSubscriptionSheetPresented = false

    var body: some View {
        Button("Manage Subscriptions") {
            isSubscriptionSheetPresented = true
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
        .manageSubscriptionsSheet(isPresented: $isSubscriptionSheetPresented, subscriptionGroupID: "21399669")
    }
}

struct PaywallView: View {
    var onDone: (Product, Result<Product.PurchaseResult, any Error>) async -> ()
    @EnvironmentObject private var purchaseManager: PurchaseManager
    var body: some View {
        VStack(spacing: 20) {
            SubscriptionStoreView(groupID: "21399669")
                .onInAppPurchaseCompletion(perform: onDone)
        }
    }
}
