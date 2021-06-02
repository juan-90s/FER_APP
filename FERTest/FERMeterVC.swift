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

class FERMeterVC: UIViewController{
    
    fileprivate var weatherView: FERWeatherView!
    var realm: Realm?
    var realmNotificationToken: NotificationToken?


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
                        }
                    }
                }
            case .error(let error):
                print("realm kvo error: \(error)")
            case .deleted:
                print("meter was deleted")
            }

        })
        setupUI()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let meter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: Date().getString()){
            print(meter)
            self.weatherView.changeWeather(weather: meter.weather, animated: false)
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.weatherView.changeWeather(weather: 0, animated: false)
    }
    

    
    func setupUI(){
        let label1 = UILabel()
        label1.font = .systemFont(ofSize: 70, weight: .bold)
        label1.textColor = .systemGray
        label1.text = "今天"
        view.addSubview(label1)
        
        weatherView = FERWeatherView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        weatherView.center = CGPoint(x: SCREEN_WIDTH/2, y: SCREEN_HEIGHT/2 + 50)
        view.addSubview(weatherView)
        
        let label2 = UILabel()
        label2.font = .systemFont(ofSize: 40, weight: .bold)
        label2.textColor = .systemGray
        label2.text = "你的心情是..."
        view.addSubview(label2)
        
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
        
    }
}
