import Foundation
import AVFoundation

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
