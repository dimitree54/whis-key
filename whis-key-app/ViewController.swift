import SwiftUI
import AVFoundation
import Foundation
import Alamofire

protocol VoiceRecorderDelegate: AnyObject {
    func didFinishRecording(successfully flag: Bool, url: URL?)
}

class VoiceRecorder: NSObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL?
    weak var delegate: VoiceRecorderDelegate?
    
    func startRecording() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let audioSession = AVAudioSession.sharedInstance()
                do {
                    try audioSession.setCategory(.record, mode: .default)
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    
                    self.recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 12000,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    
                    self.audioRecorder = try AVAudioRecorder(url: self.recordingURL!, settings: settings)
                    self.audioRecorder?.delegate = self
                    self.audioRecorder?.record()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        delegate?.didFinishRecording(successfully: flag, url: recordingURL)
    }
}

class RecorderViewModel: ObservableObject, VoiceRecorderDelegate {
    @Binding var smartMode: Bool
    @Binding var fromKeyboard: Bool
    @Published var hasSeenInstructions = false  // UserDefaults.standard.bool(forKey: "HasSeenInstructions")
    @Published var isRecording = false
    @Published var isLoading = false
    @Published var isCanceled = false
    @Published var isDone = false
    @Published var transcript = ""
    
    private var recorder = VoiceRecorder()
    
    @Published var hasPermission = false
    @Published var permissionDenied = false

    init(smartMode: Binding<Bool>, fromKeyboard: Binding<Bool>) {
        self._smartMode = smartMode
        self._fromKeyboard = fromKeyboard
        recorder.delegate = self
        checkPermission()
    }

    func checkPermission() {
        let status = AVAudioSession.sharedInstance().recordPermission
        switch status {
        case .granted:
            hasPermission = true
        case .denied:
            permissionDenied = true
        case .undetermined:
            requestPermission()
        @unknown default:
            break
        }
    }

    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    self?.hasPermission = true
                } else {
                    self?.permissionDenied = true
                }
            }
        }
    }

    func setupRecording() {
        isRecording = false
        isLoading = true
        isCanceled = false
        isDone = false
        if !hasPermission {
            checkPermission()
            return
        }

        Task {
            do {
                try await recorder.startRecording()
                isRecording = true
                isLoading = false
                isCanceled = false
                isDone = false
            } catch {
                print("Error starting the recording: \(error)")
            }
        }
    }
    
    func stopRecording() {
        recorder.stopRecording()
        isRecording = false
        isLoading = true
        isCanceled = false
        isDone = false
    }
    
    func cancelRecording() {
        recorder.stopRecording()
        isRecording = false
        isLoading = false
        isCanceled = true
        isDone = true
    }
    
    func recognise(url: URL) async {
        // Check the audio file's length
        var audioDuration: TimeInterval = 0.0
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioDuration = audioPlayer.duration
        } catch {
            print("Error getting audio file duration: \(error)")
        }
        print("Audio file duration: \(audioDuration) seconds")
        
        
        uploadAudioFile(audioFilename: url, smartMode: smartMode, completion: onRecognition)
    }
    
    func onRecognition(transcript: String?, error: Error?){
        isRecording = false
        isLoading = false
        isCanceled = false
        isDone = true
        print("writing")
        let sharedDefaults = UserDefaults(suiteName: "group.we.rashchenko")
        // Save to shared defaults and move to the background
        sharedDefaults?.set(transcript, forKey: "recognizedText")
        sharedDefaults?.synchronize()  // force saving changes
        print(sharedDefaults?.string(forKey: "recognizedText"))
        self.transcript = transcript ?? ""
    }
    
    func uploadAudioFile(audioFilename: URL, smartMode: Bool, completion: @escaping (String?, Error?) -> Void) {
        print("uploading with smartMode=\(smartMode)")
        let url = "https://rashchenko.xyz:443/recognise"
        let headers: HTTPHeaders = ["Content-type": "multipart/form-data"]
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(audioFilename, withName: "m4a_file")
            multipartFormData.append(Data("\(smartMode)".utf8), withName: "smart_mode")
        }, to: url, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                if let json = value as? [String: Any], let transcript = json["transcript"] as? String {
                    completion(transcript, nil)
                } else {
                    completion(nil, NSError(domain: "", code: 400, userInfo: ["message": "Invalid response from server"]))
                }
            case .failure(let error):
                completion(nil, error)
            }
        }
    }

    func didFinishRecording(successfully flag: Bool, url: URL?) {
        if (isCanceled){
            print("Canceled")
            return
        }
        guard flag, let recordingURL = url else {
            print("Recording was unsuccessful or the URL is nil.")
            return
        }
        
        Task {
            await recognise(url: recordingURL)
        }
    }
    
    func close(){
        isRecording = false
        isLoading = true
        isCanceled = false
        isDone = false
        Task{
            await UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        }
    }
    
    func copy2clipboard(){
        let pasteboard = UIPasteboard.general
        pasteboard.string = transcript
    }
}

struct IntroView: View {
    var onDone: () -> Void  // Declare a callback function
    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to Whis-Key!")
                .font(.largeTitle)
                .padding()
            
            Text("Follow these steps to enable Whis-Key keyboard:")
                .font(.headline)
                .padding()
            
            Text("1. Open Settings\n2. Tap General\n3. Tap Keyboard\n4. Tap Keyboards\n5. Tap Add New Keyboard\n6. Select Whis-Key")
                .padding()
            
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

struct VoiceRecognitionView: View {
    @StateObject public var viewModel: RecorderViewModel
    @State private var animationScale: CGFloat = 1.0
    @Environment(\.scenePhase) private var scenePhase
    
    init(smartMode: Binding<Bool>, fromKeyboard: Binding<Bool>) {
        self._viewModel = StateObject(wrappedValue: RecorderViewModel(smartMode: smartMode, fromKeyboard: fromKeyboard))
    }
    
    var body: some View {
        if (viewModel.hasSeenInstructions){
            VStack {
                if (!viewModel.hasPermission || viewModel.permissionDenied){
                    Text("Waiting for record permissions. Enable them in settings")
                }
                else{
                    if viewModel.isRecording {
                        Button(action: viewModel.stopRecording) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(animationScale)
                                
                                Image(systemName: "stop.fill") // SF Symbol for "stop"
                                    .foregroundColor(.white)
                                    .font(.system(size: 50))
                            }
                        }
                        .padding()
                        Toggle("", isOn: $viewModel.smartMode)
                            .labelsHidden()
                        Text("Smart mode")
                    }
                    
                    if viewModel.isLoading {
                        ProgressView() // Loading animation
                    }
                    if viewModel.isDone{
                        VStack{
                            HStack{
                                if (viewModel.fromKeyboard){
                                    VStack{
                                        Text("👆 press here to")
                                        Text("return to keyboard")
                                    }
                                }
                                Spacer()
                                Button(action: viewModel.close) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray)
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "xmark") // SF Symbol for "close"
                                            .foregroundColor(.white)
                                            .font(.system(size: 25))
                                    }
                                }.padding()
                            }
                            
                            Spacer()
                            
                            Button(action: viewModel.setupRecording) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "repeat") // SF Symbol for "repeat"
                                        .foregroundColor(.white)
                                        .font(.system(size: 50))
                                }
                            }.padding()
                            Text("Recognised text:")
                                .padding()
                                .font(.largeTitle) // This will make the text larger
                                .bold()            // This will make the text bold
                            Text(viewModel.transcript)
                            Button(action: viewModel.copy2clipboard) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 100, height: 100)
                                    Image(systemName: "doc.on.doc") // SF Symbol for "copy"
                                        .foregroundColor(.white)
                                        .font(.system(size: 50))
                                }
                            }.padding()
                            Spacer()
                        }
                    }
                }
                
            }
            .onChange(of: viewModel.isRecording) { isRecording in
                withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    animationScale = isRecording ? 1.2 : 1.0
                }
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    print("set up")
                    if (viewModel.hasSeenInstructions){
                        viewModel.setupRecording()
                    }
                case .inactive:
                    print("App is inactive")
                    viewModel.cancelRecording()
                case .background:
                    print("App is in the background")
                @unknown default:
                    print("Unknown scene phase")
                }
            }
        }
        else{
            IntroView(onDone: {
                viewModel.hasSeenInstructions = true
                UserDefaults.standard.set(true, forKey: "HasSeenInstructions")
                viewModel.setupRecording()
            })
        }
    }
}
