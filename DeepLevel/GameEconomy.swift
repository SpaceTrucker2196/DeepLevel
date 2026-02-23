import Foundation
import Combine

/// Dope Wars inspired trading economy for DeepLevel.
///
/// Players trade items across city districts where prices fluctuate
/// based on location and random events. The goal is to maximize
/// wealth by buying low and selling high while avoiding Stedenko
/// encounters and leveraging CoolBear allies.
///
/// - Since: 1.0.0
final class GameEconomy: ObservableObject {

    // MARK: - Trading Items

    /// A tradeable item with base pricing.
    struct TradingItem: Identifiable, Equatable {
        let id: String
        let name: String
        let basePrice: Int
        let description: String
        let category: TradingCategory

        static func == (lhs: TradingItem, rhs: TradingItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Categories of tradeable goods.
    enum TradingCategory: String, CaseIterable {
        case food = "Food"
        case electronics = "Electronics"
        case clothing = "Clothing"
        case curiosities = "Curiosities"
        case supplies = "Supplies"
    }

    /// District types that affect pricing.
    enum District: String, CaseIterable {
        case park = "Park"
        case residential = "Residential"
        case urban = "Urban"
        case redLight = "Red Light"
        case retail = "Retail"

        /// Price multipliers per category for each district.
        var priceMultipliers: [TradingCategory: Double] {
            switch self {
            case .park:
                return [.food: 0.6, .electronics: 1.5, .clothing: 1.0, .curiosities: 0.8, .supplies: 0.7]
            case .residential:
                return [.food: 0.9, .electronics: 1.0, .clothing: 0.7, .curiosities: 1.1, .supplies: 0.9]
            case .urban:
                return [.food: 1.1, .electronics: 0.8, .clothing: 1.2, .curiosities: 1.0, .supplies: 1.1]
            case .redLight:
                return [.food: 1.4, .electronics: 1.3, .clothing: 0.6, .curiosities: 0.5, .supplies: 1.2]
            case .retail:
                return [.food: 1.0, .electronics: 0.7, .clothing: 1.0, .curiosities: 1.2, .supplies: 0.8]
            }
        }
    }

    // MARK: - Published State

    @Published var cash: Int = 100
    @Published var debt: Int = 500
    @Published var turnsRemaining: Int = 30
    @Published var hp: Int = 10
    @Published var charmedScore: Int = 0
    @Published var currentDistrict: District = .urban
    @Published var inventory: [String: Int] = [:]
    @Published var recentEvents: [GameEvent] = []
    @Published var localPrices: [(TradingItem, Int)] = []
    @Published var currentAlgorithm: String = "CityMap"

    // MARK: - Game Events

    /// An event that occurred during gameplay.
    struct GameEvent: Identifiable {
        let id = UUID()
        let message: String
        let type: EventType

        enum EventType {
            case info, gain, loss, danger, bonus
        }
    }

    // MARK: - Static Data

    static let tradingItems: [TradingItem] = [
        TradingItem(id: "energy_bar", name: "Energy Bar", basePrice: 8, description: "A nutritious snack", category: .food),
        TradingItem(id: "water_bottle", name: "Water Bottle", basePrice: 5, description: "Clean drinking water", category: .food),
        TradingItem(id: "gourmet_coffee", name: "Gourmet Coffee", basePrice: 15, description: "Premium bean brew", category: .food),
        TradingItem(id: "street_tacos", name: "Street Tacos", basePrice: 12, description: "Delicious street food", category: .food),
        TradingItem(id: "usb_drive", name: "USB Drive", basePrice: 20, description: "Loaded with data", category: .electronics),
        TradingItem(id: "phone_charger", name: "Phone Charger", basePrice: 25, description: "Universal charger", category: .electronics),
        TradingItem(id: "headphones", name: "Headphones", basePrice: 40, description: "Noise-cancelling pair", category: .electronics),
        TradingItem(id: "smart_watch", name: "Smart Watch", basePrice: 80, description: "Barely used wearable", category: .electronics),
        TradingItem(id: "vintage_jacket", name: "Vintage Jacket", basePrice: 35, description: "Retro denim classic", category: .clothing),
        TradingItem(id: "sneakers", name: "Sneakers", basePrice: 50, description: "Limited edition kicks", category: .clothing),
        TradingItem(id: "sunglasses", name: "Sunglasses", basePrice: 18, description: "Stylish shades", category: .clothing),
        TradingItem(id: "hat", name: "Fedora Hat", basePrice: 22, description: "Mysterious headwear", category: .clothing),
        TradingItem(id: "old_coin", name: "Old Coin", basePrice: 30, description: "Rare collectible", category: .curiosities),
        TradingItem(id: "comic_book", name: "Comic Book", basePrice: 15, description: "First edition print", category: .curiosities),
        TradingItem(id: "vinyl_record", name: "Vinyl Record", basePrice: 25, description: "Classic album pressing", category: .curiosities),
        TradingItem(id: "antique_key", name: "Antique Key", basePrice: 45, description: "Opens something...", category: .curiosities),
        TradingItem(id: "first_aid", name: "First Aid Kit", basePrice: 20, description: "Basic medical supplies", category: .supplies),
        TradingItem(id: "flashlight", name: "Flashlight", basePrice: 12, description: "High-powered torch", category: .supplies),
        TradingItem(id: "lockpick", name: "Lock Pick Set", basePrice: 35, description: "Professional quality", category: .supplies),
        TradingItem(id: "map", name: "City Map", basePrice: 10, description: "Detailed area guide", category: .supplies),
    ]

    // MARK: - Computed Properties

    /// Total score combining cash, inventory value, and debt.
    var score: Int {
        cash + inventoryValue - debt
    }

    /// Total value of all inventory items at current local prices.
    var inventoryValue: Int {
        inventory.reduce(0) { total, entry in
            let itemPrice = localPrices.first(where: { $0.0.id == entry.key })?.1 ?? 0
            return total + (itemPrice * entry.value)
        }
    }

    /// Total number of items in inventory.
    var totalItems: Int {
        inventory.values.reduce(0, +)
    }

    /// Maximum inventory capacity.
    let maxInventoryCapacity: Int = 20

    // MARK: - Initialization

    init() {
        updateLocalPrices()
    }

    // MARK: - Trading

    /// Buy an item at local prices.
    /// - Returns: `true` if purchase succeeded.
    @discardableResult
    func buyItem(id: String, quantity: Int = 1) -> Bool {
        guard let priceEntry = localPrices.first(where: { $0.0.id == id }) else { return false }
        let totalCost = priceEntry.1 * quantity
        guard cash >= totalCost else {
            addEvent("Not enough cash!", type: .loss)
            return false
        }
        guard totalItems + quantity <= maxInventoryCapacity else {
            addEvent("Inventory full!", type: .loss)
            return false
        }
        cash -= totalCost
        inventory[id, default: 0] += quantity
        addEvent("Bought \(quantity)x \(priceEntry.0.name) for $\(totalCost)", type: .info)
        return true
    }

    /// Sell an item at local prices.
    /// - Returns: `true` if sale succeeded.
    @discardableResult
    func sellItem(id: String, quantity: Int = 1) -> Bool {
        guard let priceEntry = localPrices.first(where: { $0.0.id == id }) else { return false }
        guard let owned = inventory[id], owned >= quantity else {
            addEvent("Don't have enough to sell!", type: .loss)
            return false
        }
        let totalRevenue = priceEntry.1 * quantity
        cash += totalRevenue
        inventory[id, default: 0] -= quantity
        if inventory[id] == 0 { inventory.removeValue(forKey: id) }
        addEvent("Sold \(quantity)x \(priceEntry.0.name) for $\(totalRevenue)", type: .gain)
        return true
    }

    // MARK: - District & Turn Management

    /// Update the current district based on tile type.
    func updateDistrict(from tileKind: TileKind) {
        let newDistrict: District?
        switch tileKind {
        case .park, .hidingArea: newDistrict = .park
        case .residential1, .residential2, .residential3, .residential4: newDistrict = .residential
        case .urban1, .urban2, .urban3: newDistrict = .urban
        case .redLight: newDistrict = .redLight
        case .retail: newDistrict = .retail
        default: newDistrict = nil
        }
        if let district = newDistrict, district != currentDistrict {
            currentDistrict = district
            updateLocalPrices()
            addEvent("Entered \(district.rawValue) district", type: .info)
        }
    }

    /// Advance one game turn.
    func advanceTurn() {
        guard turnsRemaining > 0 else { return }
        turnsRemaining -= 1
        if turnsRemaining > 0, turnsRemaining % 5 == 0, debt > 0 {
            let interest = max(1, debt / 10)
            debt += interest
            addEvent("Debt interest: +$\(interest)", type: .danger)
        }
        if Int.random(in: 0..<5) == 0 {
            updateLocalPrices()
            addEvent("Market prices shifted!", type: .info)
        }
    }

    /// Apply bonus from charming a CoolBear.
    func applyCharmBonus() {
        let bonus = Int.random(in: 10...30)
        cash += bonus
        addEvent("CoolBear tip: +$\(bonus)!", type: .bonus)
    }

    /// Apply penalty from Stedenko encounter.
    func applyStedenkoPenalty() {
        let loss = min(cash, Int.random(in: 5...20))
        cash -= loss
        if !inventory.isEmpty, Bool.random() {
            if let randomKey = inventory.keys.randomElement() {
                let itemName = Self.tradingItems.first(where: { $0.id == randomKey })?.name ?? randomKey
                inventory[randomKey, default: 0] -= 1
                if inventory[randomKey] == 0 { inventory.removeValue(forKey: randomKey) }
                addEvent("Stedenko took your \(itemName) and $\(loss)!", type: .danger)
            }
        } else {
            addEvent("Stedenko shakedown: -$\(loss)!", type: .danger)
        }
    }

    /// Pay off debt with available cash.
    @discardableResult
    func payDebt(amount: Int) -> Bool {
        let payment = min(amount, min(cash, debt))
        guard payment > 0 else { return false }
        cash -= payment
        debt -= payment
        addEvent("Paid $\(payment) on debt", type: .gain)
        return true
    }

    /// Reset for a new game.
    func reset() {
        cash = 100
        debt = 500
        turnsRemaining = 30
        currentDistrict = .urban
        inventory = [:]
        recentEvents = []
        updateLocalPrices()
    }

    // MARK: - Price Calculation

    /// Update local prices based on current district.
    func updateLocalPrices() {
        let multipliers = currentDistrict.priceMultipliers
        localPrices = Self.tradingItems.map { item in
            let multiplier = multipliers[item.category] ?? 1.0
            let variation = Double.random(in: 0.8...1.2)
            let price = max(1, Int(Double(item.basePrice) * multiplier * variation))
            return (item, price)
        }
    }

    private func addEvent(_ message: String, type: GameEvent.EventType) {
        let event = GameEvent(message: message, type: type)
        recentEvents.insert(event, at: 0)
        if recentEvents.count > 10 {
            recentEvents = Array(recentEvents.prefix(10))
        }
    }
}
