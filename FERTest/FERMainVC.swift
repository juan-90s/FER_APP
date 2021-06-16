//
//  ViewController.swift
//  FERTest
//
//  Created by Juan Jacinto on 4/19/21.
//

import UIKit
import AVKit
import Vision
import MetalPerformanceShaders
import NotificationCenter
import RealmSwift

let SCREEN_HEIGHT = UIScreen.main.bounds.height
let SCREEN_WIDTH = UIScreen.main.bounds.width


class FERMainVC: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate{
    
    
    var meter:EmotionMeter!
    
    fileprivate var realm : Realm?
    fileprivate var ferContext = 0
    var objectNotificationToken: NotificationToken?
    
    // UI
    fileprivate var faceBoxView: UIView!
    fileprivate var monitorView: UIImageView!
    fileprivate var FerModel:VNCoreMLModel?
    fileprivate var label:UILabel!
    fileprivate var emoji:UILabel!
    fileprivate var maxFPS: Int8 = 6      //最大处理帧
    fileprivate var FPSIndex: Int8 = 0    //帧数控制器
    
    
    var sigma:Double = 0.0
    
    //懒加载
    lazy var device: MTLDevice =
    {
        return MTLCreateSystemDefaultDevice()!
    }()
        
    lazy var ciContext: CIContext =
    {
        [unowned self] in
        return CIContext(mtlDevice: self.device)
    }()
    
    let captureSession = AVCaptureSession()
    var captureDevice:AVCaptureDevice! = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 加载CNN模型
        let coreMLconfig = MLModelConfiguration()
        guard let model = try? VNCoreMLModel(for: FerCNN(configuration:coreMLconfig).model) else {
            fatalError("Unable to load the model")
        }
        self.FerModel = model
        
        
        
        let config = Realm.Configuration(
            schemaVersion: 2, // Set the new schema version.
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    migration.deleteData(forType: "EmotionMeter")
                }
            }
        )
        Realm.Configuration.defaultConfiguration = config
        // 加载数据库
        do {
            realm = try Realm()
        } catch let error as NSError {
            print("init realm instance error, \(error)")
        }
        
        // 获取今日数据
        if let today_meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()) {
            print(today_meter)
            meter = today_meter
        } else {
            meter = EmotionMeter()
            try! realm?.write({
                realm?.add(meter)
            })
        }
        meter.san = EmotionMeter.getSanFrom(weather: meter.weather)
        meter.fact = 1

        //initialize capture session
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        captureSession.startRunning()
        
        // 实时前摄图像
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
        
        //配置输出
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)

        NotificationCenter.default.addObserver(self, selector: #selector(getDebug), name: Notification.Name("changeSan"), object: nil)
        setupUI()
    }
    
    deinit {
       NotificationCenter.default.removeObserver(self)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("camera was able to capture a frame:",Date())
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 定义人脸检测请求
        let request = VNDetectFaceRectanglesRequest { (req, err)
            in
            
            if let err = err{
                print("Failed to detect faces:", err)
                return
            }
            
            req.results?.forEach({ [weak self] (res) in
                guard let faceObservation = res as? VNFaceObservation else { return }
                // 对于图像的rect
                let _x = CGFloat(CVPixelBufferGetHeight(pixelBuffer)) * faceObservation.boundingBox.origin.x
                let _y = CGFloat(CVPixelBufferGetWidth(pixelBuffer)) * faceObservation.boundingBox.origin.y
                let _width = CGFloat(CVPixelBufferGetHeight(pixelBuffer)) * faceObservation.boundingBox.width
                let _height = CGFloat(CVPixelBufferGetWidth(pixelBuffer)) * faceObservation.boundingBox.height
                let faceRect = CGRect(x: _x, y: _y, width: _width, height: _height)
                
                let ciimage = CIImage(cvPixelBuffer: pixelBuffer)
                    .oriented(.leftMirrored)
                    .applyingFilter("CIPhotoEffectMono")
                guard let cgImage:CGImage = self?.ciContext.createCGImage(ciimage, from: ciimage.extent) else { return }
                guard let croppedCGImage:CGImage = cgImage.cropping(to: faceRect) else { return }
                let croppedimage = CIImage(cgImage: croppedCGImage).transformed(by:CGAffineTransform(scaleX: 96/_width, y: 96/_height))
                let ciimage2 = self?.mpsHistEqualize(inputImage: croppedimage)
                
                self?.facialExpressionDetect(ciimage2!)
                DispatchQueue.main.async {
                    //对于view的rect
                    let x = SCREEN_WIDTH * faceObservation.boundingBox.origin.x
                    let y = SCREEN_HEIGHT * faceObservation.boundingBox.origin.y
                    let width = SCREEN_WIDTH * faceObservation.boundingBox.width
                    let height = SCREEN_HEIGHT * faceObservation.boundingBox.height
                    let boxRect = CGRect(x: x, y: y, width: width, height: height)
                    UIView.animate(withDuration: 0.25, animations: {
                        self?.faceBoxView.frame = boxRect
                        self?.label.frame = CGRect(x: x, y: y, width: 100, height: 10)
                        self?.emoji.center = CGPoint(x: x + width, y: y + height)
                    })
                }
            })
            
        }
        // 控制帧数
        FPSIndex += 1
        if FPSIndex > maxFPS {
            FPSIndex = 0
            //处理人脸检测请求
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,orientation: .left, options: [:])
            do {
                try handler.perform([request])
            } catch let reqErr {
                print("Failed to perform Face Detection request:", reqErr)
            }
        }
    }
    // 处理Fer CoreML request
    func facialExpressionDetect(_ image: CIImage){
        guard let model: VNCoreMLModel = FerModel else { return }
        let fer_request = VNCoreMLRequest(model: model){
            (finishedReq, err) in
            guard let results = finishedReq.results as? [VNClassificationObservation],
                  let firstObservation = results.first
                else { return }
            if firstObservation.confidence > 0.5 {
                let expression = firstObservation.identifier
                let confidence = firstObservation.confidence
                let emotion = Emotion(expression, confidence: confidence)
                DispatchQueue.main.async {
                    let old_weather = self.meter.weather
                    self.meter.updateSanByEmotion(emotion)
                    let san:Float = self.meter.san
                    let weather:Int = EmotionMeter.getWeatherFrom(san: san)
                    if weather != old_weather {
                        try! self.realm?.write {
                            self.meter.weather = weather
                        }
                        
                    }
                    self.label.text = firstObservation.identifier
                    switch emotion.expression {
                    case .angry:
                        self.emoji.text = "😡"
                    case .disgust:
                        self.emoji.text = "🤢"
                    case .fear:
                        self.emoji.text = "😱"
                    case .happy:
                        self.emoji.text = "😄"
                    case .neutral:
                        self.emoji.text = "😐"
                    case .sad:
                        self.emoji.text = "😔"
                    case .surprise:
                        self.emoji.text = "😯"
                    }
                    print("san: \(String(describing: self.meter.san))")
                    print("weather: \(String(describing: self.meter.weather))")
                }
            }
        }
        let fer_handler = VNImageRequestHandler(ciImage: image, options: [:])
        do{
            try fer_handler.perform([fer_request])
        } catch let reqErr {
            print("Failed to perform FER request:", reqErr)
        }
    }
    fileprivate func setupUI() {
        //UI相关
        let tabbarHeight = self.tabBarController?.tabBar.bounds.size.height ?? 0
        let statusHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        let contentRect = CGRect(x: 0, y: statusHeight, width: SCREEN_WIDTH, height: SCREEN_HEIGHT-statusHeight)
        
        //绘制Mask
        let maskLayer = CAShapeLayer()
        maskLayer.frame = contentRect
        let path = CGMutablePath()
        let outerBorderPath = UIBezierPath(rect: contentRect).cgPath
        path.addPath(outerBorderPath)
        let innerBorderPath = CGPath(
            roundedRect: CGRect(x: 20, y: 100, width: contentRect.width-40, height: contentRect.height-200),
            cornerWidth: 20,
            cornerHeight: 20,
            transform: nil)
        path.addPath(innerBorderPath)
        maskLayer.path = path
        maskLayer.fillColor = UIColor.systemGray6.cgColor
        maskLayer.strokeColor = UIColor.systemGray.cgColor
        maskLayer.fillRule = .evenOdd
        view.layer.addSublayer(maskLayer)
        
        
        
        let button = UIButton()
        button.backgroundColor = .systemBlue
        button.frame = CGRect(x: 10, y: 30 , width: 80, height: 30)
        button.setTitle("Normal FPS", for: .normal)
        button.setTitle("Slow FPS", for: .selected)
        button.setTitleColor(.lightGray, for: .selected)
        button.setTitleColor(.darkGray, for: .normal)
        button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
        button.layer.cornerRadius = 5
        //view.addSubview(button)
        
        faceBoxView = UIView()
        faceBoxView.backgroundColor = .white
        faceBoxView.alpha = 0.4
        faceBoxView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        faceBoxView.layer.cornerRadius = 5
        view.addSubview(faceBoxView)
        
        label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.frame = CGRect(x: 0, y: 0, width: 100, height: 10)
        label.textColor = .white
        view.addSubview(label)
        
        emoji = UILabel()
        emoji.font = .systemFont(ofSize: 50)
        emoji.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        emoji.textAlignment = .center
        view.addSubview(emoji)
        
        monitorView = UIImageView()
        monitorView.backgroundColor = .clear
        monitorView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        monitorView.center = CGPoint(x: SCREEN_HEIGHT/2, y: 100)
        monitorView.layer.cornerRadius = 5
        
        //高斯模糊值 指示器
//        let slider = UISlider()
//        slider.frame = CGRect(x: 0, y: 0, width: 100, height: 20)
//        slider.center = CGPoint(x: SCREEN_HEIGHT/2, y: 30)
//        slider.minimumValue = 0.0
//        slider.maximumValue = 2.0
//        slider.setValue(0.0, animated: true)
//        slider.addTarget(self, action: #selector(sliderValueChange(_:)), for: .valueChanged)
//        view.addSubview(slider)
    
        
    }
    
    //利用MPS直方图均衡化
    fileprivate func mpsHistEqualize(inputImage:CIImage) -> CIImage?{
        guard let commandQueue:MTLCommandQueue = device.makeCommandQueue() else {
            return nil
        }
        let commandBuffer = commandQueue.makeCommandBuffer()
        let colorSpace = inputImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(inputImage.extent.width),
            height: Int(inputImage.extent.height),
            mipmapped: false)
        textureDescriptor.usage = [.shaderWrite,.shaderRead]
        let sourceTexture = device.makeTexture(descriptor: textureDescriptor)
        let destinationTexture = device.makeTexture(descriptor: textureDescriptor)
        ciContext.render(inputImage, to: sourceTexture!, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: colorSpace)
        var histogramInfo = MPSImageHistogramInfo(
            numberOfHistogramEntries: 256,
            histogramForAlpha: false,
            minPixelValue: vector_float4(0,0,0,0),
            maxPixelValue: vector_float4(1,1,1,1))
        
        let calculation = MPSImageHistogram(
            device: device,
            histogramInfo: &histogramInfo)
        
        let bufferLength = calculation.histogramSize(forSourceFormat: sourceTexture!.pixelFormat)
        
        let histogramInfoBuffer = device.makeBuffer(
            bytes: &histogramInfo,
            length: bufferLength,
            options: [.storageModeShared])
        
        calculation.encode(to: commandBuffer!,
                           sourceTexture: sourceTexture!,
                           histogram: histogramInfoBuffer!,
                           histogramOffset: 0)
        
        let equalization = MPSImageHistogramEqualization(
            device: device,
            histogramInfo: &histogramInfo)
        
        equalization.encodeTransform(to: commandBuffer!, sourceTexture: sourceTexture!, histogram: histogramInfoBuffer!, histogramOffset: 0)
        equalization.encode(commandBuffer: commandBuffer!, sourceTexture: sourceTexture!, destinationTexture: destinationTexture!)
        commandBuffer?.commit()
        let ciImage = CIImage(mtlTexture: destinationTexture!, options: [:])
        
        return ciImage
    }
    
    
    @objc func tapped(_ btn:UIButton){
        if btn.isSelected {
            btn.isSelected = false
            try? captureDevice.lockForConfiguration()
            captureDevice.activeVideoMaxFrameDuration = .invalid
            captureDevice.unlockForConfiguration()
        } else {
            btn.isSelected = true
            try? captureDevice.lockForConfiguration()
            captureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 6)
            captureDevice.unlockForConfiguration()
        }
    }
    
    @objc func sliderValueChange(_ slider:UISlider) {
        sigma = Double(slider.value)
        let label:UILabel = self.view.viewWithTag(1000) as! UILabel
        label.text = String(format: "%.1d", arguments: [sigma])
    }
    @objc func getDebug() {
        meter.san = EmotionMeter.getSanFrom(weather: meter.weather)
        
    }
}

