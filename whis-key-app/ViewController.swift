import SwiftUI
import Foundation

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

struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

struct VoiceRecognitionView: View {
    @Binding var smartMode: Bool
    @Binding var fromKeyboard: Bool
    @StateObject public var viewModel: RecorderViewModel
    @State private var animationScale: CGFloat = 1.0
    @Environment(\.scenePhase) private var scenePhase
    @State private var orientation = UIDeviceOrientation.unknown
    
    var isRunningOnIpad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    func compactRequired()->Bool{
        let isLandscape = (orientation == UIDeviceOrientation.landscapeLeft || orientation == UIDeviceOrientation.landscapeRight)
        return isLandscape && !isRunningOnIpad
    }
    
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
        .onRotate { newOrientation in
            orientation = newOrientation
        }
    }
    
    private var permissionView: some View {
        Text("Waiting for record permissions. Enable them in settings")
    }
    
    private var recordingView: some View {
        VStack {
            if (viewModel.editMode){
                if (!compactRequired()){
                    Text("Tell me, what to change in that text:")
                }
                transcriptView
            }
            else{
                Text("Smart mode")
                Toggle("", isOn: $smartMode)
                    .labelsHidden()
            }
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
        }
    }
    
    private var loadingView: some View {
        ProgressView() // Loading animation
    }
    
    private var transcriptView: some View{
        VStack{
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
            if (!compactRequired()){
                Text("Recognised text:")
            }
            transcriptView.padding()
            actionsBar.padding()
        }
    }
    
    
    private var topBar: some View {
        HStack{
            if (fromKeyboard && !compactRequired()){
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
            IconButton(action: viewModel.setupRecording, bgColor: .blue, systemName: "repeat", size: 85)
            if (!compactRequired()){
                Text("Retry")
            }
        }
    }
    
    private var editButton: some View {
        VStack{
            IconButton(action: viewModel.edit, bgColor: .blue, systemName: "pencil", size: 85)
            if (!compactRequired()){
                Text("Edit")
            }
        }
    }
    
    private var copyButton: some View {
        VStack{
            IconButton(action: viewModel.copy2clipboard, bgColor: .gray, systemName: "doc.on.doc", size: 85)
            if (!compactRequired()){
                Text("Copy")
            }
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
