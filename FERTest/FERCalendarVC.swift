//
//  FERCalenderVC.swift
//  FERTest
//
//  Created by Juan Jacinto on 5/29/21.
//

import UIKit
import FSCalendar
import RealmSwift
import SnapKit

class FERCalendarVC: UIViewController, FSCalendarDataSource, FSCalendarDelegate {

    var selectedDate: String = Date().getString()
    
    fileprivate var realm: Realm?
    fileprivate weak var calendar: FSCalendar!
    fileprivate let gregorian: NSCalendar! = NSCalendar(calendarIdentifier:NSCalendar.Identifier.gregorian)
    
    fileprivate var dateLabel: UILabel!
    fileprivate var weatherView: FERWeatherView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tabbarHeight = self.tabBarController?.tabBar.bounds.size.height ?? 0
        
        do {
            realm = try Realm()
        } catch let error as NSError {
            print("init realm instance error, \(error)")
        }
        
        
        let calendar = FSCalendar(frame: CGRect(x: 0, y: 40, width: SCREEN_WIDTH, height: 400))
        calendar.dataSource = self
        calendar.delegate = self
        calendar.allowsMultipleSelection = false
        calendar.appearance.caseOptions = [.headerUsesUpperCase, .weekdayUsesSingleUpperCase]
        calendar.appearance.todayColor = .systemGray
        calendar.appearance.selectionColor = .systemYellow
        calendar.appearance.headerTitleFont = .systemFont(ofSize: 16, weight: .bold)
        calendar.appearance.imageOffset = CGPoint(x: 0, y: 5)
        self.view.addSubview(calendar)
        self.calendar = calendar
        calendar.select(Date.dateWithString(selectedDate))
        
        let todayView = UIView(frame: CGRect(x: 0, y: 40 + 400, width: SCREEN_WIDTH, height: SCREEN_HEIGHT - tabbarHeight - 40 - 400))
        view.addSubview(todayView)
        
        let lineView = UIView()
        lineView.backgroundColor = .black
        lineView.alpha = 0.5
        todayView.addSubview(lineView)

        
        dateLabel = UILabel()
        dateLabel.font = .systemFont(ofSize: 30, weight: .bold)
        dateLabel.textColor = .systemGray
        dateLabel.text = "\(gregorian.component(.year, from: Date()))年\(gregorian.component(.month, from: Date()))月\(gregorian.component(.day, from: Date()))日"
        todayView.addSubview(dateLabel)
        
        
        let label = UILabel()
        label.font = .systemFont(ofSize: 30, weight: .bold)
        label.textColor = .systemGray
        label.text = "你的心情是..."
        todayView.addSubview(label)
        
        weatherView = FERWeatherView(frame: CGRect(x: 0, y: 0, width: 140, height: 140))
        if let meter:EmotionMeter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: selectedDate) {
            let weather = meter.weather
            weatherView.changeWeather(weather: weather, animated: false)
        }
        todayView.addSubview(weatherView)
        
        
        lineView.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(0.5)
            make.centerY.equalTo(todayView.snp_topMargin)
        }
        weatherView.snp.makeConstraints { (make) in
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-10)
            make.height.equalTo(140)
            make.width.equalTo(140)
        }
        dateLabel.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(30)
        }
        
        label.snp.makeConstraints { (make) in
            make.top.equalTo(dateLabel.snp_bottomMargin).offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(30)
        }
        
        
    }
    
    override  func  viewDidLayoutSubviews() {
        super .viewDidLayoutSubviews()
        
    }
    
    // MARK:- FSCalendarDataSource
    func calendar(_ calendar: FSCalendar, titleFor date: Date) -> String? {
        return self.gregorian.isDateInToday(date) ? "Today" : nil
    }
    
    func calendar(_ calendar: FSCalendar, imageFor date: Date) -> UIImage? {
        let dateString:String = date.getString()
        guard let meter:EmotionMeter = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: dateString) else { return nil }
        print(meter)
        let weather = meter.weather
        var image:UIImage?
        switch weather {
        case 1:
            image = UIImage(systemName: "sun.max.fill")
        case 2:
            image = UIImage(systemName: "sun.haze.fill")
        case 3:
            image = UIImage(systemName: "cloud.sun.fill")
        case 4:
            image = UIImage(systemName: "cloud.sun.rain.fill")
        case 5:
            image = UIImage(systemName: "cloud.rain.fill")
        case 6:
            image = UIImage(systemName: "cloud.heavyrain.fill")
        case 7:
            image = UIImage(systemName: "cloud.bolt.rain.fill")
        default:
            image = nil
        }
        return image?.withTintColor(.systemGray5)
    }
    // MARK:- FSCalendarDelegate
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        print("change page to \(calendar.currentPage.getString())")
    }
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectedDate = date.getString()
        dateLabel.text = "\(gregorian.component(.year, from: date))年\(gregorian.component(.month, from: date))月\(gregorian.component(.day, from: date))日"
        
        let meter:EmotionMeter? = realm?.object(ofType: EmotionMeter.self, forPrimaryKey: selectedDate)
        let weather = meter?.weather ?? 0
        weatherView.changeWeather(weather: weather, animated: false)
        
        if monthPosition == .previous || monthPosition == .next {
            calendar.setCurrentPage(date, animated: true)
        }
    }

}
