//
//  FERIntroVC.swift
//  FERTest
//
//  Created by Juan Jacinto on 5/29/21.
//

import UIKit
import Lottie
import RealmSwift
import SnapKit
import AVKit

class FERMeterVC: UIViewController{
    
    fileprivate var weatherView: FERWeatherView!
    fileprivate var muteBtn: UIButton!
    fileprivate var audioPlayer1: AVAudioPlayer!
    fileprivate var audioPlayer2: AVAudioPlayer!
    
    fileprivate var debugBtn: UIButton!
    fileprivate var debugBtn1: UIButton!
    fileprivate var debugBtn2: UIButton!
    fileprivate var debugBtn3: UIButton!
    fileprivate var debugBtn4: UIButton!
    fileprivate var debugBtn5: UIButton!
    fileprivate var debugBtn6: UIButton!
    fileprivate var debugBtn7: UIButton!
    
    var realm: Realm?
    var realmNotificationToken: NotificationToken?
    var isMute = false

    deinit {
        realmNotificationToken?.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 加载数据库
        do {
            realm = try Realm()
        } catch let error as NSError {
            print("init realm instance error, \(error)")
        }
        
        guard let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()) else { return }
        realmNotificationToken = meter.observe({ change in
            switch change {
            case .change(let object, let properties):
                for property in properties {
                    guard let newValue = property.newValue as? Int
                        else { return }
                    
                    if property.name == "weather" {
                        print("In object\(object),the \(property.name) was changed to \(String(describing: property.newValue))")
                        DispatchQueue.main.async {
                            self.weatherView.changeWeather(weather: newValue, animated: true)
                            self.playAudioIn(weather: newValue)
                        }
                    }
                }
            case .error(let error):
                print("realm kvo error: \(error)")
            case .deleted:
                print("meter was deleted")
            }

        })
        //初始化播放器
        self.audioPlayer1 = try! AVAudioPlayer(contentsOf: urlForMP3("silence"))
        self.audioPlayer2 = try! AVAudioPlayer(contentsOf: urlForMP3("silence"))
        self.audioPlayer1.numberOfLoops = -1
        self.audioPlayer2.numberOfLoops = -1
        self.audioPlayer1.volume = 0
        self.audioPlayer2.volume = 0
        setupUI()
        
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            print(meter)
            self.weatherView.changeWeather(weather: meter.weather, animated: false)
            self.playAudioIn(weather: meter.weather)
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.weatherView.changeWeather(weather: 0, animated: false)
    }
    

    
    func setupUI(){
        
        let tabbarHeight = self.tabBarController?.tabBar.bounds.size.height ?? 0
        
        let label1 = UILabel()
        label1.font = .systemFont(ofSize: 70, weight: .bold)
        label1.textColor = .systemGray
        label1.text = "今天"
        view.addSubview(label1)
        
        weatherView = FERWeatherView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        weatherView.center = CGPoint(x: SCREEN_WIDTH/2, y: SCREEN_HEIGHT/2 + 50)
        view.addSubview(weatherView)
        
        muteBtn = UIButton()
        muteBtn.setImage(UIImage(systemName: "speaker.fill"), for: .normal)
        muteBtn.setImage(UIImage(systemName: "speaker.slash"), for: .selected)
        muteBtn.setTitleColor(.systemBlue, for: .normal)
        muteBtn.setTitleColor(.systemGray, for: .selected)
        muteBtn.addTarget(self, action: #selector(mute), for: .touchUpInside)
        view.addSubview(muteBtn)
        
        let label2 = UILabel()
        label2.font = .systemFont(ofSize: 40, weight: .bold)
        label2.textColor = .systemGray
        label2.text = "你的心情是..."
        view.addSubview(label2)
        
        muteBtn.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(30)
            make.right.equalToSuperview().offset(-30)
            make.height.equalTo(50)
            make.width.equalTo(50)
        }
        muteBtn.imageView!.snp.makeConstraints { (make) in
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.left.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        label1.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(30)
            make.top.equalToSuperview().offset(100)
            make.right.equalToSuperview().offset(-30)
            make.height.equalTo(70)
        }
        
        label2.snp.makeConstraints { (make) in
            make.top.equalTo(label1.snp_bottomMargin).offset(30)
            make.left.equalToSuperview().offset(30)
            make.right.equalToSuperview().offset(-30)
            make.height.equalTo(40)
        }
        
        let debugView = UIView()
        view.addSubview(debugView)
        debugView.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview().offset( -tabbarHeight-20)
            make.left.equalToSuperview().offset(60)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(40)
        }
        
        debugBtn = UIButton()
        debugBtn.setImage(UIImage(systemName: "ladybug"), for: .normal)
        debugBtn.setImage(UIImage(systemName: "ladybug.fill"), for: .selected)
        debugBtn.addTarget(self, action: #selector(debug), for: .touchUpInside)
        view.addSubview(debugBtn)
        debugBtn.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview().offset( -tabbarHeight-20)
            make.left.equalToSuperview().offset(20)
            make.centerY.equalTo(debugView.snp_centerYWithinMargins)
            make.height.equalTo(20)
            make.width.equalTo(20)
        }
        
        debugBtn1 = UIButton()
        debugBtn1.setImage(UIImage(systemName: "sun.max.fill"), for: .normal)
        debugBtn1.addTarget(self, action: #selector(debug1), for: .touchUpInside)
        debugView.addSubview(debugBtn1)
        debugBtn1.snp.makeConstraints { (make) in
            make.centerY.equalTo(debugView.snp_centerYWithinMargins)
            make.left.equalToSuperview().offset(20)
            make.height.equalTo(20)
            make.width.equalTo(20)
        }
        
        debugBtn2 = UIButton()
        debugBtn2.setImage(UIImage(systemName: "sun.haze.fill"), for: .normal)
        debugBtn2.addTarget(self, action: #selector(debug2), for: .touchUpInside)
        debugView.addSubview(debugBtn2)
        debugBtn2.snp.makeConstraints { (make) in
            make.centerY.equalTo(debugView.snp_centerYWithinMargins)
            make.left.equalToSuperview().offset(60)
            make.height.equalTo(20)
            make.width.equalTo(20)
        }
        
        debugBtn3 = UIButton()
        debugBtn3.setImage(UIImage(systemName: "cloud.sun.fill"), for: .normal)
        debugBtn3.addTarget(self, action: #selector(debug3), for: .touchUpInside)
        debugView.addSubview(debugBtn3)
        debugBtn3.snp.makeConstraints { (make) in
            make.centerY.equalTo(debugView.snp_centerYWithinMargins)
            make.left.equalToSuperview().offset(100)
            make.height.equalTo(20)
            make.width.equalTo(20)
        }
        
        debugBtn4 = UIButton()
        debugBtn4.setImage(UIImage(systemName: "cloud.sun.rain.fill"), for: .normal)
        debugBtn4.addTarget(self, action: #selector(debug4), for: .touchUpInside)
        debugView.addSubview(debugBtn4)
        debugBtn4.snp.makeConstraints { (make) in
            make.centerY.equalTo(debugView.snp_centerYWithinMargins)
            make.left.equalToSuperview().offset(140)
            make.height.equalTo(20)
            make.width.equalTo(20)
        }
        
        debugBtn5 = UIButton()
        debugBtn5.setImage(UIImage(systemName: "cloud.rain.fill"), for: .normal)
        debugBtn5.addTarget(self, action: #selector(debug5), for: .touchUpInside)
        debugView.addSubview(debugBtn5)
        debugBtn5.snp.makeConstraints { (make) in
            make.centerY.equalTo(debugView.snp_centerYWithinMargins)
            make.left.equalToSuperview().offset(180)
            make.height.equalTo(20)
            make.width.equalTo(20)
        }
        
        debugBtn6 = UIButton()
        debugBtn6.setImage(UIImage(systemName: "cloud.heavyrain.fill"), for: .normal)
        debugBtn6.addTarget(self, action: #selector(debug6), for: .touchUpInside)
        debugView.addSubview(debugBtn6)
        debugBtn6.snp.makeConstraints { (make) in
            make.centerY.equalTo(debugView.snp_centerYWithinMargins)
            make.left.equalToSuperview().offset(220)
            make.height.equalTo(20)
            make.width.equalTo(20)
        }
        
        debugBtn7 = UIButton()
        debugBtn7.setImage(UIImage(systemName: "cloud.bolt.rain.fill"), for: .normal)
        debugBtn7.addTarget(self, action: #selector(debug7), for: .touchUpInside)
        debugView.addSubview(debugBtn7)
        debugBtn7.snp.makeConstraints { (make) in
            make.centerY.equalTo(debugView.snp_centerYWithinMargins)
            make.left.equalToSuperview().offset(260)
            make.height.equalTo(20)
            make.width.equalTo(20)
        }
        
        debugBtn1.isHidden = true
        debugBtn2.isHidden = true
        debugBtn3.isHidden = true
        debugBtn4.isHidden = true
        debugBtn5.isHidden = true
        debugBtn6.isHidden = true
        debugBtn7.isHidden = true
    }
    func playAudioIn(weather:Int = 0) {
        if(isMute){
            return
        }
        //取音源
        var sound_name:String?
        switch weather {
        case 1:
            sound_name = "bird_sound2"
        case 2:
            sound_name = "bird_sound"
        case 3:
            sound_name = "wind_sound"
        case 4:
            sound_name = "gentle_rain"
        case 5:
            sound_name = "gentle_rain"
        case 6:
            sound_name = "rain"
        case 7:
            sound_name = "thuder_rain"
        default:
            sound_name = "silence"
        }
        
        if(audioPlayer1.volume == 0)&&(audioPlayer2.volume == 0){
            //初始化
            self.audioPlayer1 = try! AVAudioPlayer(contentsOf: urlForMP3(sound_name!))
            self.audioPlayer1.volume = 1
            self.audioPlayer1.numberOfLoops = -1
            self.audioPlayer1.play()
        } else if(audioPlayer2.volume != 0){
            self.audioPlayer2.setVolume(0, fadeDuration: 2)
            self.audioPlayer1 = try! AVAudioPlayer(contentsOf: urlForMP3(sound_name!))
            self.audioPlayer1.volume = 1
            self.audioPlayer1.numberOfLoops = -1
            self.audioPlayer1.play()
        } else if(audioPlayer1.volume != 0){
            self.audioPlayer1.setVolume(0, fadeDuration: 2)
            self.audioPlayer2 = try! AVAudioPlayer(contentsOf: urlForMP3(sound_name!))
            self.audioPlayer2.volume = 1
            self.audioPlayer2.numberOfLoops = -1
            self.audioPlayer2.play()
        }
    }
    fileprivate func urlForMP3(_ fileName:String) -> URL{
        return Bundle.main.url(forResource: fileName, withExtension: "mp3")!
    }
    @objc func mute() {
        if isMute {
            isMute = false
            muteBtn.isSelected = false
            audioPlayer2.play()
            audioPlayer1.play()
        } else {
            isMute = true
            muteBtn.isSelected = true
            audioPlayer2.stop()
            audioPlayer1.stop()
        }
    }
    
    @objc func debug() {
        if debugBtn.isSelected {
            debugBtn.isSelected = false
            debugBtn1.isHidden = true
            debugBtn2.isHidden = true
            debugBtn3.isHidden = true
            debugBtn4.isHidden = true
            debugBtn5.isHidden = true
            debugBtn6.isHidden = true
            debugBtn7.isHidden = true
        } else {
            debugBtn.isSelected = true
            debugBtn1.isHidden = false
            debugBtn2.isHidden = false
            debugBtn3.isHidden = false
            debugBtn4.isHidden = false
            debugBtn5.isHidden = false
            debugBtn6.isHidden = false
            debugBtn7.isHidden = false
        }
    }
    @objc func debug1() {
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            try! self.realm?.write {
                meter.weather = 1
            }
            NotificationCenter.default.post(name: NSNotification.Name("changeSan"), object: nil, userInfo: ["san":90])
        }
    }
    @objc func debug2() {
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            try! self.realm?.write {
                meter.weather = 2
            }
            NotificationCenter.default.post(name: NSNotification.Name("changeSan"), object: nil, userInfo: ["san":70])
        }
    }
    @objc func debug3() {
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            try! self.realm?.write {
                meter.weather = 3
            }
            NotificationCenter.default.post(name: NSNotification.Name("changeSan"), object: nil, userInfo: ["san":50])
        }
    }
    @objc func debug4() {
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            try! self.realm?.write {
                meter.weather = 4
            }
            NotificationCenter.default.post(name: NSNotification.Name("changeSan"), object: nil, userInfo: ["san":35])
        }
    }
    @objc func debug5() {
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            try! self.realm?.write {
                meter.weather = 5
            }
            NotificationCenter.default.post(name: NSNotification.Name("changeSan"), object: nil, userInfo: ["san":25])
        }
    }
    @objc func debug6() {
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            try! self.realm?.write {
                meter.weather = 6
            }
            NotificationCenter.default.post(name: NSNotification.Name("changeSan"), object: nil, userInfo: ["san":15])
        }
    }
    @objc func debug7() {
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            try! self.realm?.write {
                meter.weather = 7
            }
            NotificationCenter.default.post(name: NSNotification.Name("changeSan"), object: nil, userInfo: ["san":5])
        }
    }
}
