import SwiftUI
import AVFoundation
import Foundation
import Alamofire

protocol VoiceRecorderDelegate: AnyObject {
    func didFinishRecording(successfully flag: Bool, url: URL?)
}

class VoiceRecorder: NSObject, AVAudioRecorderDelegate {
    private(set) var audioRecorder: AVAudioRecorder?
    private(set) var recordingURL: URL?
    private var delegate: VoiceRecorderDelegate?
    
    private var audioSession: AVAudioSession {
        return AVAudioSession.sharedInstance()
    }
    
    func startRecording(delegate: VoiceRecorderDelegate) throws {
        self.delegate = delegate
        try self.configureAudioSession()
        try self.setupAudioRecorder()
        self.audioRecorder?.record()
    }
    
    private func configureAudioSession() throws {
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func setupAudioRecorder() throws {
        self.recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        self.audioRecorder = try AVAudioRecorder(url: self.recordingURL!, settings: settings)
        self.audioRecorder?.delegate = self
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        delegate?.didFinishRecording(successfully: flag, url: recordingURL)
    }
}


class VoiceRecorderWrapper: ObservableObject, VoiceRecorderDelegate {
    private var recorder = VoiceRecorder()
    private var delegate: VoiceRecorderDelegate?
    
    @Published var isRecording = false
    @Published var hasPermission = false

    func requestPermission() async {
        // Request permission to record.
        if await AVAudioApplication.requestRecordPermission() {
            self.hasPermission = true
        } else {
            self.hasPermission = false
        }
    }
    func startRecording(delegate: VoiceRecorderDelegate) async throws {
        isRecording = false
        if !hasPermission {
            await requestPermission()
        }
        self.delegate = delegate
        try recorder.startRecording(delegate: self)
        isRecording = true
    }
    func stopRecording() {
        recorder.stopRecording()
        isRecording = false
    }
    func didFinishRecording(successfully flag: Bool, url: URL?) {
        self.isRecording = false
        self.delegate?.didFinishRecording(successfully: flag, url: url)
    }
    
}


class AudioRecognitionService {
    let endpointUrl = "https://rashchenko.xyz:443/recognise"
    
    func recognise(audioFilename: URL, smartMode: Bool, completion: @escaping (String?, Error?) -> Void) {
        let headers: HTTPHeaders = ["Content-type": "multipart/form-data"]
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(audioFilename, withName: "m4a_file")
            multipartFormData.append(Data("\(smartMode)".utf8), withName: "smart_mode")
        }, to: endpointUrl, headers: headers)
        .responseDecodable(of: AudioRecognitionResponse.self) { response in
            switch response.result {
            case .success(let recognitionResponse):
                completion(recognitionResponse.transcript, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}

struct AudioRecognitionResponse: Decodable {
    let transcript: String?
}

class ClipboardManager {
    func copyToClipboard(text: String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
    }
}


class RecorderViewModel: ObservableObject, VoiceRecorderDelegate {
    @Binding var smartMode: Bool
    @Binding var fromKeyboard: Bool
    
    @Published var hasSeenInstructions = UserDefaults.standard.bool(forKey: "HasSeenInstructions")
    @Published var isLoading = false
    @Published var isCanceled = false
    @Published var isDone = false
    @Published var transcript = ""
    
    var voiceRecorderWrapper = VoiceRecorderWrapper()
    private var audioRecognitionService = AudioRecognitionService()
    private var clipboardManager = ClipboardManager()
    
    init(smartMode: Binding<Bool>, fromKeyboard: Binding<Bool>) {
        self._smartMode = smartMode
        self._fromKeyboard = fromKeyboard
    }
    
    func setupRecording() {
        isCanceled = false
        isDone = false
        isLoading = true
        Task{
            do{
                try await voiceRecorderWrapper.startRecording(delegate: self)
            }
            catch{
                transcript = error.localizedDescription
                isDone = true
            }
            isLoading = false
        }
    }
    func cancelRecording() {
        voiceRecorderWrapper.stopRecording()
        isLoading = false
        isCanceled = true
        isDone = true
    }
    func onRecognition(transcript: String?, error: Error?) {
        isLoading = false
        isDone = true
        
        if let error = error {
            self.transcript = error.localizedDescription
        } else {
            self.transcript = transcript ?? "Unknown recognition error"
        }
        
        let sharedDefaults = UserDefaults(suiteName: "group.we.rashchenko")
        sharedDefaults?.set(self.transcript, forKey: "recognizedText")
        sharedDefaults?.synchronize()
    }
    func didFinishRecording(successfully flag: Bool, url: URL?) { 
        if (isCanceled){
            transcript = "Recognition cancelled"
            return
        }
        guard flag, let recordingURL = url else {
            transcript = "Recording was unsuccessful or file URL is nil."
            return
        }
        isLoading = true
        self.audioRecognitionService.recognise(audioFilename: recordingURL, smartMode: smartMode, completion: onRecognition)
    }
    func close(){
        cancelRecording()
        Task{
            await UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        }
    }
    func copy2clipboard() {
        clipboardManager.copyToClipboard(text: transcript)
    }
}

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
            .tag(1)
            
        }
        .tabViewStyle(PageTabViewStyle())  // Page control style for TabView
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))  // Display page indicator
    }
}

struct IconButton: View {
    var action: () -> Void
    var bgColor: Color
    var systemName: String
    var size: CGFloat
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: size, height: size)
                
                Image(systemName: systemName)
                    .foregroundColor(.white)
                    .font(.system(size: size / 2))
            }
        }
        .padding()
    }
}

struct VoiceRecognitionView: View {
    @Binding var smartMode: Bool
    @Binding var fromKeyboard: Bool
    @StateObject public var viewModel: RecorderViewModel
    @State private var animationScale: CGFloat = 1.0
    @Environment(\.scenePhase) private var scenePhase
    
    init(smartMode: Binding<Bool>, fromKeyboard: Binding<Bool>) {
        self._smartMode = smartMode
        self._fromKeyboard = fromKeyboard
        self._viewModel = StateObject(wrappedValue: RecorderViewModel(smartMode: smartMode, fromKeyboard: fromKeyboard))
    }
    
    var body: some View {
        if (viewModel.hasSeenInstructions) {
            mainView
        }
        else {
            IntroView(onDone: setupInstructionsAndRecording)
        }
    }
    
    private var mainView: some View {
        VStack {
            if !viewModel.voiceRecorderWrapper.hasPermission {
                permissionView
            }
            else if viewModel.voiceRecorderWrapper.isRecording {
                recordingView
            }
            else if viewModel.isDone {
                doneView
            }
            else{
                loadingView
            }
        }
        .onChange(of: viewModel.voiceRecorderWrapper.isRecording){
            handleRecordingChange(isRecording: viewModel.voiceRecorderWrapper.isRecording)
        }
        .onChange(of: scenePhase){
            handleScenePhaseChange(newPhase: scenePhase)
        }
    }
    
    private var permissionView: some View {
        Text("Waiting for record permissions. Enable them in settings")
    }
    
    private var recordingView: some View {
        VStack {
            Text("Recording...")
            Button(action: viewModel.voiceRecorderWrapper.stopRecording) {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 100, height: 100)
                        .scaleEffect(animationScale)
                    Image(systemName: "stop.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 100 / 2))
                }
            }
            .padding()
            Toggle("", isOn: $smartMode)
                .labelsHidden()
            Text("Smart mode")
        }
    }
    
    private var loadingView: some View {
        ProgressView() // Loading animation
    }
    
    private var transcriptView: some View{
        VStack{
            Text("Recognised text:")
            ScrollView {
                Text(viewModel.transcript)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
            .background(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.gray, lineWidth: 1))
        }
    }
    
    private var actionsBar: some View{
        HStack{
            repeatButton
            editButton
            copyButton
        }
    }
    
    private var doneView: some View {
        VStack{
            topBar.padding()
            Spacer()
            transcriptView.padding()
            actionsBar
        }
    }
    
    private var topBar: some View {
        HStack{
            if (fromKeyboard){
                VStack{
                    Text("👆 press here to")
                    Text("return to keyboard")
                }
            }
            Spacer()
        }
        .padding()
    }
    
    private var repeatButton: some View {
        VStack{
            IconButton(action: viewModel.setupRecording, bgColor: .blue, systemName: "repeat", size: 100)
            Text("Retry")
        }
    }
    
    private var editButton: some View {
        VStack{
            IconButton(action: viewModel.setupRecording, bgColor: .blue, systemName: "pencil", size: 100)
            Text("Edit")
        }
    }
    
    private var copyButton: some View {
        VStack{
            IconButton(action: viewModel.copy2clipboard, bgColor: .gray, systemName: "doc.on.doc", size: 100)
            Text("Copy")
        }
        
    }
    
    private func handleRecordingChange(isRecording: Bool) {
        withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            animationScale = isRecording ? 1.2 : 1.0
        }
    }
    
    private func handleScenePhaseChange(newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if (viewModel.hasSeenInstructions) {
                viewModel.setupRecording()
            }
        case .inactive:
            viewModel.cancelRecording()
        case .background:
            break
        @unknown default:
            break
        }
    }
    
    private func setupInstructionsAndRecording() {
        viewModel.hasSeenInstructions = true
        UserDefaults.standard.set(true, forKey: "HasSeenInstructions")
        viewModel.setupRecording()
    }
}
