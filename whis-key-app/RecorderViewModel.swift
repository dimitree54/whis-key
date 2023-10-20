import Foundation
import SwiftUI


class IntroState: ObservableObject {
    @Published var acceptedAgreement = UserDefaults.standard.bool(forKey: "acceptedAgreement")
    @Published var enabledKeyboard = UserDefaults.standard.bool(forKey: "enabledKeyboard")
}


class RecorderViewModel: ObservableObject, VoiceRecorderDelegate {
    @Binding var smartMode: Bool
    @Binding var fromKeyboard: Bool
    
    @Published var editMode = false
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
    
    func edit(){
        editMode = true
        setupRecording()
    }
    
    func cancelRecording() {
        voiceRecorderWrapper.stopRecording()
        isLoading = false
        isCanceled = true
        isDone = true
        editMode = false
    }
    func onRecognition(transcript: String?, error: Error?) {
        isLoading = false
        isDone = true
        editMode = false
        
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
        if (editMode){
            self.audioRecognitionService.edit(audioFilename: recordingURL, text2edit: transcript, completion: onRecognition)
        }
        else{
            self.audioRecognitionService.recognise(audioFilename: recordingURL, smartMode: smartMode, completion: onRecognition)
        }
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
