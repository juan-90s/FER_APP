//
//  FERWeatherView.swift
//  FERTest
//
//  Created by Juan Jacinto on 5/29/21.
//

import UIKit
import Lottie


class FERWeatherView: UIView {
    //var firstImageView:UIImageView!
    //var secondImageView:UIImageView!
    var animationView: AnimationView!
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
        let width = frame.width
        let height = frame.height
        //firstImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: width))
        //firstImageView.backgroundColor = .clear
        
        //secondImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: width))
        //secondImageView.backgroundColor = .clear
        animationView = AnimationView()
        animationView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        self.addSubview(animationView)
    }
    
    func changeWeather(weather:Int, animated: Bool){
        var animation:Animation?
        switch weather {
        case 1:
            animation = Animation.named("Sun")
        case 2:
            animation = Animation.named("Haze")
        case 3:
            animation = Animation.named("Cloud")
        case 4:
            animation = Animation.named("RainCloud")
        case 5:
            animation = Animation.named("RainyWeather")
        case 6:
            animation = Animation.named("TorrentialRain")
        case 7:
            animation = Animation.named("StormyWeather")
        default:
            animation = nil
        }
        appear(animation,animated: animated)
        
    }
    
    func appear(_ animation:Animation? , animated:Bool) {
        DispatchQueue.main.async {
            let width = self.frame.width
            let height = self.frame.height
            self.animationView.animation = animation
            self.animationView.play()
            if animated {
                self.animationView.center = CGPoint(x: 0, y: 0)
                self.animationView.alpha = 0
                UIView.animate(withDuration: 1, delay: 0, animations: {
                    self.animationView.center = CGPoint(x: width/2, y: height/2)
                    self.animationView.alpha = 1.0
                })
            }
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
}
