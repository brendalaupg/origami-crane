/*:
 # Hi! My name is Brenda!
 And this is my WWDC 2018 Scholarship Submission, an Origami Crane Tutorial and Image Recognizer!
 Folding origami and using computers has been a part of my life since I was 7. With CoreML and Vison frameworks, I thought, why not put the two together!
 
 # Instructions
1. Before starting, prepare a square sheet of paper!
2. Tap on the start button when you're ready! Full screen gives the best experience!
3. To use the image recognition feature, tap the camera icon.
4. If you would like to look at each individual fold, tap on the animated diagrams!
5. The image recognition will verify if the step is complete when it has 60% confidence or more!

 Happy Folding!
*/

import PlaygroundSupport
import AVKit
import Vision

@available(iOS 11.0, *)
class OrigamiViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer()
    let captureSession: AVCaptureSession = AVCaptureSession()
    
    var startButton: UIButton = UIButton(type: .system)
    var stepLabel: UILabel = UILabel()
    var nextStepButton: UIButton = UIButton(type: .system)
    var previousStepButton: UIButton = UIButton(type: .system)
    
    var cameraButton: UIButton = UIButton(type: .system)
    var successButton: UIButton = UIButton(type: .system)
    var backgroundImageView: UIImageView = UIImageView()
    
    var messageContainerView: UIView = UIView()
    var messageLabel: UILabel = UILabel()
    
    var instructionsContainerView: UIView = UIView()
    var instructionsTitleLabel: UILabel = UILabel()
    var instructionsContentLabel: UILabel = UILabel()
    
    var detailsLabel: UILabel = UILabel()
    var detailsButton: UIButton = UIButton()
    var diagramContainerView: UIView = UIView()
    var diagramImageView: UIImageView =  UIImageView()
    
    var detailsContainerView: UIView = UIView()
    var detailsDiagramImageView: UIImageView = UIImageView()
    var detailsInstructionsTitleLabel: UILabel = UILabel()
    var detailsInstructionsContentLabel: UILabel = UILabel()
    var previousDiagramButton: UIButton = UIButton(type: .system)
    var nextDiagramButton: UIButton = UIButton(type: .system)
    var closeButton: UIButton = UIButton(type: .system)
    
    var origamiArray: [Origami] = [Origami]()
    var currentOrigami: Origami = Origami()
    var currentDiagramNo: Int = 0
    var isCameraOn: Bool = false
    var origamiModel: VNCoreMLModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.setupOrigamiModel()
        self.setupOrigamiData()
        self.setupCaptureSession()
        self.setupUI()
    }
    
    func setupOrigamiModel() {
        do {
            if let origamiVNCoreMLModel: VNCoreMLModel = try VNCoreMLModel(for: OrigamiCrane().model) {
                self.origamiModel = origamiVNCoreMLModel
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            if self.origamiModel == nil {
                print("Its empty!")
            }
            if let origamiModel = self.origamiModel {
                print("origami")
                let coreMLRequest: VNCoreMLRequest = VNCoreMLRequest(model: origamiModel) { (request: VNRequest, error: Error?) in
                    if let error: Error = error {
                        print(error.localizedDescription)
                    }
                    if let results: [VNClassificationObservation] = request.results as? [VNClassificationObservation],
                        let top3Results: [VNClassificationObservation] = [results[0], results[1], results[3]],
                        let name: String = self.currentOrigami.name,
                        let classification: String = self.currentOrigami.coremlClassification {
                        for result in top3Results where result.identifier == classification {
                            let percentage = String(format: "%.2f", (result.confidence * 100))
                            
                            DispatchQueue.main.async {
                                self.messageLabel.text = "I'm \(percentage)% think its a \(name)"
                                if result.confidence > 0.6 {
                                    self.autoDetectCompleteStep(name: name)
                                    self.messageLabel.text = "You've folded a \(name)"
                                }
                            }
                        }
                    }
                }
                try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([coreMLRequest])
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Frame was dropped!")
        print(sampleBuffer)
    }
    
    private func setupCaptureSession() {
        self.captureSession.sessionPreset = .medium
        guard let captureDevice: AVCaptureDevice = AVCaptureDevice.default(for: .video),
            let captureInput: AVCaptureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        self.captureSession.beginConfiguration()
        if self.captureSession.canAddInput(captureInput) {
            self.captureSession.addInput(captureInput)
        }
        self.captureSession.commitConfiguration()
        
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 20)
            captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 20)
            captureDevice.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
        
        self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.view.layer.addSublayer(videoPreviewLayer)
        
        let dataOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        
        dataOutput.alwaysDiscardsLateVideoFrames = true
        let videoQueue: DispatchQueue = DispatchQueue(label: "videoQueue", qos: .background, attributes: .concurrent, autoreleaseFrequency: .workItem, target: DispatchQueue.global())
        dataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        self.videoPreviewLayer.frame = self.view.frame
        self.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.getOrientation()
        captureSession.addOutput(dataOutput)
    }
    
    @objc private func previousButtonTapped(button: UIButton) {
        if let currentOrigami: Origami = self.currentOrigami,
            currentOrigami.stepNo! > 1 {
            let currentStep = currentOrigami.stepNo ?? 1
            self.setCurrentOrigami(origami: self.origamiArray[currentStep - 2])
        }
    }
    
    @objc private func nextButtonTapped(button: UIButton) {
        if let currentOrigami: Origami = self.currentOrigami,
            currentOrigami.stepNo! < self.origamiArray.count {
            let currentStep = currentOrigami.stepNo ?? 1
            self.setCurrentOrigami(origami: self.origamiArray[currentStep])
        }
    }
    
    @objc private func successButtonTapped(button: UIButton) {
        let alert: UIAlertController = UIAlertController(title: "Completed Step?", message: "Have you completed this step?", preferredStyle: .alert)
        let noAction: UIAlertAction = UIAlertAction(title: "No", style: .destructive, handler: nil)
        let yesAction: UIAlertAction = UIAlertAction(title: "Yes", style: .default, handler:  { (alert: UIAlertAction) in
            self.turnOffCamera()
            DispatchQueue.main.async {
                self.messageLabel.text = "You've folded a \(self.currentOrigami.name ?? "")"
                self.successButton.tintColor = #colorLiteral(red: 0.466666668653488, green: 0.764705896377563, blue: 0.266666680574417, alpha: 1.0)
            }
            if self.currentOrigami.stepNo == 9 {
                self.finishedOrigami()
            }
        })
        alert.addAction(noAction)
        alert.addAction(yesAction)
        
        if self.successButton.tintColor == #colorLiteral(red: 0.501960813999176, green: 0.501960813999176, blue: 0.501960813999176, alpha: 1.0) {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func autoDetectCompleteStep(name: String) {
        let alert: UIAlertController = UIAlertController(title: "Completed Step!", message: "You've folded a \(name)! Want to proceed to the next step right away?", preferredStyle: .alert)
        let noAction: UIAlertAction = UIAlertAction(title:"Not right now", style: .default, handler: nil)
        let yesAction: UIAlertAction = UIAlertAction(title: "Sure", style: .default, handler: { (alert: UIAlertAction) in
            self.turnOffCamera()
            if let currentStepNo: Int = self.currentOrigami.stepNo {
                self.setCurrentOrigami(origami: self.origamiArray[currentStepNo])
            }
        })
        alert.addAction(noAction)
        alert.addAction(yesAction)
        
        if self.currentOrigami.stepNo == 9 {
            self.finishedOrigami()
        } else {
            DispatchQueue.main.async {
                self.captureSession.stopRunning()
                self.successButton.tintColor = #colorLiteral(red: 0.466666668653488, green: 0.764705896377563, blue: 0.266666680574417, alpha: 1.0)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    @objc private func cameraButtonTapped(button: UIButton) {
        if self.isCameraOn {
            self.turnOffCamera()
        } else {
            self.turnOnCamera()
        }
    }
    
    private func turnOffCamera() {
        self.captureSession.stopRunning()
        self.isCameraOn = false
        DispatchQueue.main.async {
            self.cameraButton.tintColor = #colorLiteral(red: 0.501960813999176, green: 0.501960813999176, blue: 0.501960813999176, alpha: 1.0)
            self.backgroundImageView.isHidden = false
        }
    }
    
    private func turnOnCamera() {
        self.captureSession.startRunning()
        self.isCameraOn = true
        DispatchQueue.main.async {
            self.cameraButton.tintColor = #colorLiteral(red: 0.466666668653488, green: 0.764705896377563, blue: 0.266666680574417, alpha: 1.0)
            self.backgroundImageView.isHidden = true
        }
    }
    
    @objc private func previousDiagramButtonTapped(button: UIButton) {
        if self.currentDiagramNo > 0 {
            self.currentDiagramNo -= 1
            self.detailsDiagramImageView.image = self.currentOrigami.diagrams[currentDiagramNo]
            self.checkDiagramButtons()
        }
    }
    
    @objc private func nextDiagramButtonTapped(button: UIButton) {
        if self.currentDiagramNo < (self.currentOrigami.diagrams.count - 1){
            self.currentDiagramNo += 1
            self.detailsDiagramImageView.image = self.currentOrigami.diagrams[currentDiagramNo]
            self.checkDiagramButtons()
        }
    }
    
    private func checkDiagramButtons() {
        self.previousDiagramButton.isHidden = currentDiagramNo == 0 ? true : false
        self.nextDiagramButton.isHidden = currentDiagramNo == (self.currentOrigami.diagrams.count - 1) ? true : false
    }
    
    @objc private func detailsButtonTapped(button: UIButton) {
        self.turnOffCamera()
        self.diagramImageView.image = nil
        self.detailsContainerView.isHidden = false
        self.nextDiagramButton.isHidden = false
        self.previousDiagramButton.isHidden = false
        self.checkDiagramButtons()
        UIView.animate(withDuration: 1, animations: { 
            self.detailsContainerView.alpha = 1
        })
    }
    
    @objc private func closeDetailsButtonTapped(button: UIButton) {
        let isCameraOn: Bool = self.isCameraOn
        
        if self.isCameraOn {
            self.turnOffCamera()
        }
        
        UIView.animate(withDuration: 0.3, animations: { 
            self.detailsContainerView.alpha = 0
        }, completion: {
            (value: Bool) in
            self.detailsContainerView.isHidden = true
            self.diagramImageView.image = UIImage.animatedImage(with: self.currentOrigami.diagrams, duration: 10)
            self.diagramImageView.startAnimating()
            if isCameraOn {
                self.turnOnCamera()
            }
        })
    }
    
    @objc private func startButtonTapped(button: UIButton) {
        UIView.animate(withDuration: 1, animations: { 
            self.startButton.alpha = 0
            self.detailsButton.alpha = 1
            self.nextStepButton.alpha = 1
            self.cameraButton.alpha = 1
            self.successButton.alpha = 1
            self.instructionsTitleLabel.alpha = 1
            self.instructionsContainerView.alpha = 0.35
            self.diagramContainerView.alpha = 0.35
        }, completion: {
            (value: Bool) in
            self.startButton.isHidden = true
            self.detailsLabel.isHidden = false
            self.detailsButton.isEnabled = true
            self.nextStepButton.isEnabled = true
            self.cameraButton.isEnabled = true
            self.successButton.isEnabled = true
            self.setCurrentOrigami(origami: self.origamiArray[0])
        })
    }
    
    private func finishedOrigami() {
        let alert: UIAlertController = UIAlertController(title: "Congradulations", message: "Congrats! You've folded an Origami Crane!", preferredStyle: .alert)
        let hurrayAction: UIAlertAction = UIAlertAction(title: "Hurray", style: .default, handler: { (alert: UIAlertAction) in
            self.messageLabel.text = "You've folded an Origami Crane!"
        })
        alert.addAction(hurrayAction)
        
        DispatchQueue.main.async {
            self.captureSession.stopRunning()
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func setupUI() {
        //startButton
        self.startButton.setTitle("Let's Start!", for: .normal)
        self.startButton.setTitleColor(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), for: .normal)
        self.startButton.backgroundColor = #colorLiteral(red: 0.341176480054855, green: 0.623529434204102, blue: 0.168627455830574, alpha: 1.0)
        self.startButton.layer.cornerRadius = 8
        self.startButton.addTarget(self, action: #selector(OrigamiViewController.startButtonTapped(button:)), for: .touchUpInside )
        
        //previousStepButton
        if let previousIcon: UIImage = self.loadImageFromResource(resourceName: "back-arrow", subdirectory: "Icons") {
        self.previousStepButton.setImage(previousIcon, for: .normal)
        self.previousDiagramButton.setImage(previousIcon, for: .normal)
        self.previousStepButton.tintColor = #colorLiteral(red: 0.466666668653488, green: 0.764705896377563, blue: 0.266666680574417, alpha: 1.0)
        self.previousDiagramButton.tintColor = #colorLiteral(red: 0.466666668653488, green: 0.764705896377563, blue: 0.266666680574417, alpha: 1.0)
        }
        
        self.previousStepButton.isHidden = true
        self.previousStepButton.addTarget(self, action: #selector(OrigamiViewController.previousButtonTapped(button:)), for: .touchUpInside)
        self.previousDiagramButton.addTarget(self, action: #selector(OrigamiViewController.previousDiagramButtonTapped(button:)), for: .touchUpInside)
        
        //stepLabel
        self.stepLabel.textColor = #colorLiteral(red: 0.341176480054855, green: 0.623529434204102, blue: 0.168627455830574, alpha: 1.0)
        self.stepLabel.shadowColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.stepLabel.shadowOffset = CGSize(width: -1, height: 1)
        self.stepLabel.font = UIFont.boldSystemFont(ofSize: 22)
        self.stepLabel.textAlignment = .center
        
        //nextStepButton
        if let nextIcon: UIImage = self.loadImageFromResource(resourceName: "next-arrow", subdirectory: "Icons") {
            self.nextStepButton.setImage(nextIcon, for: .normal)
            self.nextDiagramButton.setImage(nextIcon, for: .normal)
            self.nextStepButton.tintColor = #colorLiteral(red: 0.466666668653488, green: 0.764705896377563, blue: 0.266666680574417, alpha: 1.0)
            self.nextDiagramButton.tintColor = #colorLiteral(red: 0.466666668653488, green: 0.764705896377563, blue: 0.266666680574417, alpha: 1.0)
        }
        self.nextStepButton.alpha = 0
        self.nextStepButton.addTarget(self, action: #selector(OrigamiViewController.nextButtonTapped(button:)), for: .touchUpInside)
        self.nextDiagramButton.addTarget(self, action: #selector(OrigamiViewController.nextDiagramButtonTapped(button:)), for: .touchUpInside)
        
        //successButton
        if let successIcon: UIImage = self.loadImageFromResource(resourceName: "success", subdirectory: "Icons") {
            self.successButton.setImage(successIcon, for: .normal)
            self.successButton.tintColor = #colorLiteral(red: 0.501960813999176, green: 0.501960813999176, blue: 0.501960813999176, alpha: 1.0)
        }
        
        self.successButton.addTarget(self, action: #selector(OrigamiViewController.successButtonTapped(button:)), for: .touchUpInside)
        self.successButton.alpha = 0
        
        //cameraButton
        if let cameraIcon: UIImage = self.loadImageFromResource(resourceName: "photo-camera", subdirectory: "Icons") {
            self.cameraButton.setImage(cameraIcon, for: .normal)
            self.cameraButton.tintColor = #colorLiteral(red: 0.501960813999176, green: 0.501960813999176, blue: 0.501960813999176, alpha: 1.0)
        }
        
        self.cameraButton.addTarget(self, action: #selector(OrigamiViewController.cameraButtonTapped(button:)), for: .touchUpInside)
        self.cameraButton.alpha = 0
        
        //backgroundImageView
        if let backgroundImage: UIImage = self.loadImageFromResource(resourceName: "background", subdirectory: "Icons") {
            self.backgroundImageView.image = backgroundImage
            self.backgroundImageView.contentMode = .scaleAspectFill
        }
        
        //messageContainerView
        self.messageContainerView.backgroundColor = #colorLiteral(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.messageContainerView.alpha = 0.35
        self.messageContainerView.layer.masksToBounds = false
        self.messageContainerView.layer.cornerRadius = 10
        
        //messageLabel
        self.messageLabel.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.messageLabel.font = UIFont.boldSystemFont(ofSize: 16)
        self.messageLabel.textAlignment = .center
        self.messageLabel.text = "Get a square sheet of paper and let's get started!"
        
        //diagramContainerView
        self.diagramContainerView.backgroundColor = #colorLiteral(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.diagramContainerView.alpha = 0
        self.diagramContainerView.layer.masksToBounds = false
        self.diagramContainerView.layer.cornerRadius = 15
        
        //instructionsContainerView
        self.instructionsContainerView.backgroundColor = #colorLiteral(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.instructionsContainerView.alpha = 0
        self.instructionsContainerView.layer.masksToBounds = false
        self.instructionsContainerView.layer.cornerRadius = 15
        
        //instructionsTitleLabel
        self.instructionsTitleLabel.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.instructionsTitleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        self.instructionsTitleLabel.text = "Instructions"
        self.instructionsTitleLabel.textAlignment = .left
        self.instructionsTitleLabel.alpha = 0
        
        //instructionsContentLabel
        self.instructionsContentLabel.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.instructionsContentLabel.font = UIFont.systemFont(ofSize: 15)
        self.instructionsContentLabel.textAlignment = .left
        self.instructionsContentLabel.numberOfLines = 7
        
        //detailsLabel
        self.detailsLabel.text = "Click for More Details"
        self.detailsLabel.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.detailsLabel.shadowColor = #colorLiteral(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.detailsLabel.font = UIFont.systemFont(ofSize: 13)
        self.detailsLabel.textAlignment = .center
        self.detailsLabel.isHidden = true
        
        //detailsButton
        self.detailsButton.addTarget(self, action: #selector(OrigamiViewController.detailsButtonTapped(button:)), for: .touchUpInside)
        self.detailsButton.isEnabled = false
        
        //detailsContainerView
        self.detailsContainerView.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.detailsContainerView.isHidden = true
        
        //detailsDiagramImageView
        self.detailsDiagramImageView.backgroundColor = #colorLiteral(red: 0.803921580314636, green: 0.803921580314636, blue: 0.803921580314636, alpha: 1.0)
        
        //detailsInstructioTitleLabel
        self.detailsInstructionsTitleLabel.text = "Instructions"
        self.detailsInstructionsTitleLabel.textColor = #colorLiteral(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.detailsInstructionsTitleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        self.detailsInstructionsTitleLabel.textAlignment = .left
        
        //detailsInstructionContentLabel
        self.detailsInstructionsContentLabel.textColor = #colorLiteral(red: 0.254901975393295, green: 0.274509817361832, blue: 0.301960796117783, alpha: 1.0)
        self.detailsInstructionsContentLabel.font = UIFont.systemFont(ofSize: 18)
        self.detailsInstructionsContentLabel.textAlignment = .left
        self.detailsInstructionsContentLabel.numberOfLines = 7
        
        //closeButton
        if let closeIcon: UIImage = self.loadImageFromResource(resourceName: "delete", subdirectory: "Icons") {
            self.closeButton.setImage(closeIcon, for: .normal)
            self.closeButton.tintColor = .red
        }
        self.closeButton.addTarget(self, action: #selector(OrigamiViewController.closeDetailsButtonTapped(button:)), for: .touchUpInside)
        
        //constraints
        let margin = self.view.layoutMarginsGuide
        self.setupSubViews(views: [backgroundImageView, startButton, previousStepButton, stepLabel, nextStepButton, successButton, cameraButton, messageContainerView, messageLabel, instructionsContainerView, instructionsTitleLabel, instructionsContentLabel, diagramContainerView, diagramImageView, detailsLabel, detailsButton, detailsContainerView])
            
        self.setupDetailSubView(views: [detailsDiagramImageView, detailsInstructionsTitleLabel, detailsInstructionsContentLabel, closeButton, nextDiagramButton, previousDiagramButton])
 
        DispatchQueue.main.async {
            self.pinAroundView(toPinView: self.backgroundImageView, targetView: self.view, constant: 0)
            
            self.startButton.centerXAnchor.constraint(equalTo: margin.centerXAnchor).isActive = true
            self.startButton.centerYAnchor.constraint(equalTo: margin.centerYAnchor).isActive = true
            self.startButton.widthAnchor.constraint(equalToConstant: 150).isActive = true
            self.startButton.heightAnchor.constraint(equalToConstant: 75).isActive = true
            
            self.stepLabel.centerXAnchor.constraint(equalTo: margin.centerXAnchor).isActive = true
            self.stepLabel.topAnchor.constraint(equalTo: margin.topAnchor).isActive = true
            self.stepLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
            self.stepLabel.widthAnchor.constraint(equalToConstant: 200).isActive = true
            
            self.previousStepButton.topAnchor.constraint(equalTo: margin.topAnchor).isActive = true
            self.previousStepButton.trailingAnchor.constraint(equalTo: self.stepLabel.leadingAnchor).isActive = true
            self.previousStepButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
            self.previousStepButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
            
            self.nextStepButton.topAnchor.constraint(equalTo: margin.topAnchor).isActive = true
            self.nextStepButton.leadingAnchor.constraint(equalTo: self.stepLabel.trailingAnchor).isActive = true
            self.nextStepButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
            self.nextStepButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
            
            self.messageLabel.topAnchor.constraint(equalTo: self.stepLabel.bottomAnchor, constant: 8).isActive = true
            self.messageLabel.leadingAnchor.constraint(equalTo: margin.leadingAnchor, constant: 8).isActive = true
            self.messageLabel.trailingAnchor.constraint(equalTo: margin.trailingAnchor, constant: -8).isActive = true
            self.messageLabel.heightAnchor.constraint(equalToConstant: 30).isActive = true
            
            self.cameraButton.topAnchor.constraint(equalTo: self.messageLabel.bottomAnchor, constant: 8).isActive = true
            self.cameraButton.leadingAnchor.constraint(equalTo: margin.leadingAnchor, constant: 8).isActive = true
            self.cameraButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
            self.cameraButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
            
            self.successButton.topAnchor.constraint(equalTo: self.messageLabel.bottomAnchor, constant: 8).isActive = true
            self.successButton.trailingAnchor.constraint(equalTo: margin.trailingAnchor, constant: -8).isActive = true
            self.successButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
            self.successButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
            
            self.instructionsContainerView.bottomAnchor.constraint(equalTo: margin.bottomAnchor, constant: -8).isActive = true
            self.instructionsContainerView.trailingAnchor.constraint(equalTo: self.diagramContainerView.leadingAnchor, constant: -8).isActive = true
            self.instructionsContainerView.leadingAnchor.constraint(equalTo: margin.leadingAnchor, constant: 8).isActive = true
            self.instructionsContainerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true
            self.instructionsContainerView.heightAnchor.constraint(equalToConstant: 150).isActive = true
            
            self.instructionsTitleLabel.topAnchor.constraint(equalTo: self.instructionsContainerView.topAnchor, constant: 8).isActive = true
            self.instructionsTitleLabel.leadingAnchor.constraint(equalTo: self.instructionsContainerView.leadingAnchor, constant: 16).isActive = true
            self.instructionsTitleLabel.heightAnchor.constraint(equalToConstant: 15).isActive = true
            
            self.instructionsContentLabel.topAnchor.constraint(equalTo: self.instructionsTitleLabel.bottomAnchor).isActive = true
            self.instructionsContentLabel.leadingAnchor.constraint(equalTo: self.instructionsContainerView.leadingAnchor, constant: 16).isActive = true
            self.instructionsContentLabel.trailingAnchor.constraint(equalTo: self.instructionsContainerView.trailingAnchor, constant: -16).isActive = true
            self.instructionsContentLabel.bottomAnchor.constraint(equalTo: self.instructionsContainerView.bottomAnchor, constant: -8).isActive = true
            
            self.detailsLabel.topAnchor.constraint(equalTo: self.diagramContainerView.topAnchor, constant: 0).isActive = true
            self.detailsLabel.leadingAnchor.constraint(equalTo: self.diagramContainerView.leadingAnchor).isActive = true
            self.detailsLabel.trailingAnchor.constraint(equalTo: margin.trailingAnchor, constant: -8).isActive = true
            
            self.diagramContainerView.bottomAnchor.constraint(equalTo: margin.bottomAnchor, constant: -8).isActive = true
            self.diagramContainerView.trailingAnchor.constraint(equalTo: margin.trailingAnchor, constant: -8).isActive = true
            self.diagramContainerView.widthAnchor.constraint(equalToConstant: 150).isActive = true
            self.diagramContainerView.heightAnchor.constraint(equalToConstant: 150).isActive = true
            
            self.diagramImageView.widthAnchor.constraint(equalToConstant: 150).isActive = true
            self.diagramImageView.heightAnchor.constraint(equalToConstant: 150).isActive = true
            
            self.pinAroundView(toPinView: self.messageContainerView, targetView: self.messageLabel, constant: 0)
            self.pinAroundView(toPinView: self.diagramImageView, targetView: self.diagramContainerView, constant: 0)
            self.pinAroundView(toPinView: self.detailsButton, targetView: self.diagramContainerView, constant: 0)
            self.pinAroundView(toPinView: self.detailsContainerView, targetView: self.view, constant: 0)
            
            let detailsMargin = self.detailsContainerView.layoutMarginsGuide
            
            self.detailsDiagramImageView.topAnchor.constraint(equalTo: detailsMargin.topAnchor, constant: 16).isActive = true
            self.detailsDiagramImageView.centerXAnchor.constraint(equalTo: detailsMargin.centerXAnchor).isActive = true
            self.detailsDiagramImageView.heightAnchor.constraint(equalToConstant: 300).isActive = true
            self.detailsDiagramImageView.widthAnchor.constraint(equalToConstant: 300).isActive = true
            
            self.detailsInstructionsTitleLabel.topAnchor.constraint(equalTo: self.detailsDiagramImageView.bottomAnchor).isActive = true
            self.detailsInstructionsTitleLabel.leadingAnchor.constraint(equalTo: detailsMargin.leadingAnchor).isActive = true
            self.detailsInstructionsTitleLabel.trailingAnchor.constraint(equalTo: detailsMargin.trailingAnchor).isActive = true
            self.detailsInstructionsTitleLabel.heightAnchor.constraint(equalToConstant: 30).isActive = true
            
            self.detailsInstructionsContentLabel.topAnchor.constraint(equalTo: self.detailsInstructionsTitleLabel.bottomAnchor).isActive = true
            self.detailsInstructionsContentLabel.leadingAnchor.constraint(equalTo: detailsMargin.leadingAnchor).isActive = true
            self.detailsInstructionsContentLabel.trailingAnchor.constraint(equalTo: detailsMargin.trailingAnchor).isActive = true
            self.detailsInstructionsContentLabel.bottomAnchor.constraint(equalTo: detailsMargin.bottomAnchor, constant: 8).isActive = true
            
            self.closeButton.topAnchor.constraint(equalTo: detailsMargin.topAnchor, constant: 8).isActive = true
            self.closeButton.leadingAnchor.constraint(equalTo: detailsMargin.leadingAnchor, constant: 8).isActive = true
            self.closeButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
            self.closeButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
            
            self.previousDiagramButton.centerYAnchor.constraint(equalTo: self.detailsDiagramImageView.centerYAnchor).isActive = true
            self.previousDiagramButton.trailingAnchor.constraint(equalTo: self.detailsDiagramImageView.leadingAnchor, constant: -8).isActive = true
            self.previousDiagramButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
            self.previousDiagramButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
            
            self.nextDiagramButton.centerYAnchor.constraint(equalTo: self.detailsDiagramImageView.centerYAnchor).isActive = true
            self.nextDiagramButton.leadingAnchor.constraint(equalTo: self.detailsDiagramImageView.trailingAnchor, constant: 8).isActive = true
            self.nextDiagramButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
            self.nextDiagramButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        }
    }
    
    private func setupSubViews(views: [UIView]) {
        for subview in views {
            self.view.addSubview(subview)
            subview.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    private func setupDetailSubView(views: [UIView]) {
        for view in views {
            self.detailsContainerView.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    //sets constraint around another view
    private func pinAroundView(toPinView: UIView, targetView: UIView, constant: CGFloat) {
        DispatchQueue.main.async {
            toPinView.topAnchor.constraint(equalTo: targetView.topAnchor, constant: constant).isActive = true
            toPinView.leadingAnchor.constraint(equalTo: targetView.leadingAnchor, constant: constant).isActive = true
            toPinView.trailingAnchor.constraint(equalTo: targetView.trailingAnchor, constant: -constant).isActive = true
            toPinView.bottomAnchor.constraint(equalTo: targetView.bottomAnchor, constant: -constant).isActive = true
        }
    }
    
    //loading the icons
    private func loadImageFromResource(resourceName: String, subdirectory: String) -> UIImage? {
        guard let imageURL: URL = Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: subdirectory) else { return nil }
        
        do {
            let imageData: Data = try Data(contentsOf: imageURL)
            if let image: UIImage = UIImage(data: imageData) {
                return image
            }
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
    
    private func readJsonData(resourceName: String) -> [String: AnyObject]? {
        do {
            if let jsonFileURL: URL = Bundle.main.url(forResource: resourceName, withExtension: "json") {
                let data: Data = try Data(contentsOf: jsonFileURL, options: .mappedIfSafe)
                let object = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                
                return object as! [String : AnyObject]
            }
        } catch {
            print("Could not fetch data")
            print(error.localizedDescription)
        }
        return nil
    }
    
    private func setupOrigamiData() {
        if let json: [String: AnyObject] = self.readJsonData(resourceName: "OrigamiData") as? [String: AnyObject] {
            if let origamiJsonArray: [Any] = json["origami"] as? [Any] {
                for origamiJson in origamiJsonArray {
                    let origami: Origami = Origami(json: origamiJson as! [String: AnyObject])
                    self.origamiArray.append(origami)
                }
            }
        }
    }
    
    //to be called for every new step
    private func setCurrentOrigami(origami: Origami) {
        self.currentOrigami = origami
        self.currentDiagramNo = 0
        self.previousDiagramButton.isHidden = true
        self.successButton.tintColor = #colorLiteral(red: 0.501960813999176, green: 0.501960813999176, blue: 0.501960813999176, alpha: 1.0)
        
        DispatchQueue.main.async {
            self.stepLabel.text = "\(origami.stepNo ?? 1)/9 - \(origami.name ?? "")"
            self.instructionsContentLabel.text = origami.instructions
            self.detailsInstructionsContentLabel.text = origami.instructions
            self.diagramImageView.image = UIImage.animatedImage(with: origami.diagrams, duration: 15)
            self.detailsDiagramImageView.image = origami.diagrams.first
            
            if let stepNo: Int = origami.stepNo {
                self.previousStepButton.isHidden = stepNo == 1 ? true : false
                self.nextStepButton.isHidden = stepNo == self.origamiArray.count ? true : false
            }
        }
    }
    
    private func getOrientation() {
        let deviceSize = UIScreen.main.bounds.size
        if deviceSize.width < deviceSize.height {
            self.videoPreviewLayer.connection?.videoOrientation = .portrait
        } else {
            self.videoPreviewLayer.connection?.videoOrientation = .landscapeRight
        }
    }
}

class Origami {
    var name: String? //based on Model's classification
    var diagrams: [UIImage] = [UIImage]()
    var instructions: String = ""
    var stepNo: Int?
    var coremlClassification: String?
    
    init() { }
    
    init(json: [String: AnyObject]) {
        print(json)
        guard let name: String = json["name"] as? String,
            let instructions: String = json["instructions"] as? String,
            let resouceNames: [String] = json["resource_names"] as? [String],
            let subdirectory: String = json["sub_directory"] as? String,
            let stepNo: Int = json["step_no"] as? Int,
            let coremlClass: String = json["coreml_class"] as? String
            else {
                print("Failed to init Origami object")
                return
        }
        
        self.name = name
        self.instructions = instructions
        self.stepNo = stepNo
        self.coremlClassification = coremlClass
        
        for resouceName in resouceNames {
            if let diagram: UIImage = self.loadImageFromResource(resourceName: resouceName, subdirectory: subdirectory) {
                self.diagrams.append(diagram)
            }
        }
    }
    
    private func loadImageFromResource(resourceName: String, subdirectory: String) -> UIImage? {
        guard let imageURL: URL = Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: subdirectory) else { return nil }
        
        do {
            let imageData: Data = try Data(contentsOf: imageURL)
            if let image: UIImage = UIImage(data: imageData) {
                return image
            }
        } catch {
            print("Could not find resource")
            return nil
        }
        return nil
    }
}

if #available(iOSApplicationExtension 11.0, *) {
    let origamiViewController: UIViewController = OrigamiViewController()
    let nav = UINavigationController(rootViewController: origamiViewController)
    PlaygroundPage.current.liveView = nav
}
PlaygroundPage.current.needsIndefiniteExecution = true

