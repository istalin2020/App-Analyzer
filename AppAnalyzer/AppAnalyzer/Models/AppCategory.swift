import Foundation
import SwiftUI

/// All app categories available for filtering
enum AppCategory: String, CaseIterable, Identifiable, Codable {
    case productivity = "Productivity"
    case games = "Games"
    case socialMedia = "Social Media"
    case banking = "Banking & Finance"
    case travel = "Travel"
    case news = "News & Magazines"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case healthFitness = "Health & Fitness"
    case education = "Education"
    case foodDrink = "Food & Drink"
    case utilities = "Utilities"
    case photography = "Photography"
    case music = "Music"
    case weather = "Weather"
    case navigation = "Navigation"
    case communication = "Communication"
    case lifestyle = "Lifestyle"
    case sports = "Sports"
    case business = "Business"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .productivity: return "briefcase.fill"
        case .games: return "gamecontroller.fill"
        case .socialMedia: return "person.2.fill"
        case .banking: return "banknote.fill"
        case .travel: return "airplane"
        case .news: return "newspaper.fill"
        case .entertainment: return "tv.fill"
        case .shopping: return "cart.fill"
        case .healthFitness: return "heart.fill"
        case .education: return "graduationcap.fill"
        case .foodDrink: return "fork.knife"
        case .utilities: return "wrench.and.screwdriver.fill"
        case .photography: return "camera.fill"
        case .music: return "music.note"
        case .weather: return "cloud.sun.fill"
        case .navigation: return "map.fill"
        case .communication: return "message.fill"
        case .lifestyle: return "sparkles"
        case .sports: return "sportscourt.fill"
        case .business: return "building.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .productivity: return .blue
        case .games: return .purple
        case .socialMedia: return .pink
        case .banking: return .green
        case .travel: return .orange
        case .news: return .red
        case .entertainment: return .indigo
        case .shopping: return .teal
        case .healthFitness: return .red
        case .education: return .cyan
        case .foodDrink: return .orange
        case .utilities: return .gray
        case .photography: return .yellow
        case .music: return .pink
        case .weather: return .cyan
        case .navigation: return .blue
        case .communication: return .green
        case .lifestyle: return .purple
        case .sports: return .orange
        case .business: return .blue
        }
    }
}
