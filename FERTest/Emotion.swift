//
//  Expression.swift
//  FERTest
//
//  Created by Juan Jacinto on 5/29/21.
//

import Foundation
import RealmSwift

enum Expression: String{
    case angry
    case disgust
    case fear
    case happy
    case neutral
    case sad
    case surprise
}
class Emotion {
    let expression:Expression
    let confidence:Float
    
    init(_ name: String, confidence:Float) {
        self.confidence = confidence
        switch name {
        case "angry":
            expression = .angry
        case "disgust":
            expression = .disgust
        case "fear":
            expression = .fear
        case "happy":
            expression = .happy
        case "neutral":
            expression = .neutral
        case "sad":
            expression = .sad
        case "surprise":
            expression = .surprise
            
        default:
            expression = .neutral
        }
    }
}

class EmotionMeter: Object {
    @objc dynamic var weather:Int = 0
    @objc dynamic var date:String = {
        let date = Date()
        return date.getString()
    }()
    var staticFact:Float = 0.5
    var fact:Float = 0
    var san:Float = 50
    
    override static func primaryKey() -> String? {
        return "date"
    }
    
    
    func updateSanByEmotion(_ emotion:Emotion) {
        if fact == 0{
            fact = staticFact
        }
        if emotion.confidence < 0.5 {
            return
        }
        
        switch emotion.expression {
        case .angry:
            fact += 0.04 * staticFact
            san -= 1 * fact
        case .disgust:
            fact -= 0.02 * staticFact
            san -= 1 * fact
        case .fear:
            fact += 0.02 * staticFact
            san -= 1 * fact
        case .happy:
            san += 1 * fact
        case .neutral:
            if fact > staticFact {
                fact -= 0.02 * staticFact
            } else if fact < staticFact {
                fact = staticFact
            }
            if san > 50 {
                san -= 0.2 * fact
            } else if san < 50 {
                san += 0.2 * fact
            }
        case .sad:
            san -= 1 * fact
        case .surprise:
            fact += 0.02 * staticFact
        }
        if san > 100 {
            san = 100
        } else if san <= 0 {
            san = 0
        }
        if fact > 2 * staticFact {
            fact = 1.9 * staticFact
        } else if fact < staticFact {
            fact = staticFact
        }
    }
    
    static func getWeatherFrom(san:Float) -> Int {
        var weather:Int = 0
        switch san {
        case 80...100:
            weather = 1
        case 60..<80:
            weather = 2
        case 40..<60:
            weather = 3
        case 30..<40:
            weather = 4
        case 20..<30:
            weather = 5
        case 10..<20:
            weather = 6
        case 0..<10:
            weather = 7
        default:
            break
        }
        return weather
    }
    static func getSanFrom(weather:Int) -> Float {
        var san:Float = 50
        switch weather {
        case 1:
            san = 90
        case 2:
            san = 70
        case 3:
            san = 50
        case 4:
            san = 35
        case 5:
            san = 25
        case 6:
            san = 15
        case 7:
            san = 5
        default:
            break
        }
        return san
    }
}

extension Date{
    func getString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: self)
    }
    static func dateWithString(_ string:String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: string)
        return date
    }
}
