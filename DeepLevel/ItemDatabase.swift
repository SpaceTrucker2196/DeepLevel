import Foundation

/// Database of items that can be found on the street and in trash.
///
/// Contains collections of random items that the player can discover and collect
/// during gameplay, representing the kinds of things one might find in an urban environment.
struct ItemDatabase {
    
    /// Categories of items available in the game.
    enum ItemCategory {
        case streetJunk
        case valuable
        case useful
        case food
        case curious
    }
    
    /// Definition of an item with its properties.
    struct ItemDefinition {
        let name: String
        let description: String
        let category: ItemCategory
        let value: Int // Could be used for trading or scoring
    }
    
    /// Complete database of available items.
    static let allItems: [ItemDefinition] = [
        // Street Junk
        ItemDefinition(name: "Bottle Cap", description: "A rusty bottle cap, probably from a soda.", category: .streetJunk, value: 1),
        ItemDefinition(name: "Chewing Gum", description: "Pre-chewed gum stuck to paper. Gross.", category: .streetJunk, value: 1),
        ItemDefinition(name: "Cigarette Butt", description: "A discarded cigarette filter. Smells terrible.", category: .streetJunk, value: 1),
        ItemDefinition(name: "Candy Wrapper", description: "Colorful wrapper from some long-eaten candy.", category: .streetJunk, value: 1),
        ItemDefinition(name: "Plastic Fork", description: "A broken plastic fork, missing a tine.", category: .streetJunk, value: 2),
        ItemDefinition(name: "Napkin", description: "A used napkin with questionable stains.", category: .streetJunk, value: 1),
        ItemDefinition(name: "Rubber Band", description: "A stretched-out rubber band.", category: .streetJunk, value: 2),
        ItemDefinition(name: "Paper Clip", description: "A bent paper clip that's seen better days.", category: .streetJunk, value: 2),
        
        // Valuable Items
        ItemDefinition(name: "Quarter", description: "A shiny quarter! Someone's loss is your gain.", category: .valuable, value: 25),
        ItemDefinition(name: "Dime", description: "A small silver coin worth ten cents.", category: .valuable, value: 10),
        ItemDefinition(name: "Penny", description: "A copper penny, still counts as money!", category: .valuable, value: 1),
        ItemDefinition(name: "Earring", description: "A single gold-colored earring. Where's its mate?", category: .valuable, value: 15),
        ItemDefinition(name: "Button", description: "An ornate button from someone's fancy coat.", category: .valuable, value: 5),
        ItemDefinition(name: "Ring", description: "A ring with a fake-looking gem. Or is it real?", category: .valuable, value: 30),
        
        // Useful Items
        ItemDefinition(name: "Hair Tie", description: "A stretchy hair tie that could be useful.", category: .useful, value: 3),
        ItemDefinition(name: "Shoelace", description: "A spare shoelace in surprisingly good condition.", category: .useful, value: 5),
        ItemDefinition(name: "Band-Aid", description: "A sterile bandage still in its wrapper.", category: .useful, value: 8),
        ItemDefinition(name: "Safety Pin", description: "A small safety pin that could come in handy.", category: .useful, value: 4),
        ItemDefinition(name: "Pencil Stub", description: "A well-used pencil, still has some lead left.", category: .useful, value: 6),
        ItemDefinition(name: "Matches", description: "A book of matches with a few left.", category: .useful, value: 10),
        ItemDefinition(name: "Tissue Pack", description: "A travel pack of tissues, mostly full.", category: .useful, value: 7),
        
        // Food Items
        ItemDefinition(name: "Mints", description: "A roll of breath mints, two left.", category: .food, value: 5),
        ItemDefinition(name: "Energy Bar", description: "A partially eaten energy bar. Still good?", category: .food, value: 12),
        ItemDefinition(name: "Apple Core", description: "The remains of someone's healthy snack.", category: .food, value: 2),
        ItemDefinition(name: "Crackers", description: "A pack of crackers, slightly crushed.", category: .food, value: 8),
        ItemDefinition(name: "Water Bottle", description: "A plastic water bottle, empty but clean.", category: .food, value: 6),
        ItemDefinition(name: "Coffee Cup", description: "A disposable coffee cup with a sip left.", category: .food, value: 3),
        
        // Curious Items
        ItemDefinition(name: "Fortune Cookie Slip", description: "A fortune that reads: 'Adventure awaits around every corner.'", category: .curious, value: 4),
        ItemDefinition(name: "Business Card", description: "A business card for 'Jimmy's Fish Emporium.'", category: .curious, value: 3),
        ItemDefinition(name: "Receipt", description: "A receipt for $47.83 worth of cat food.", category: .curious, value: 2),
        ItemDefinition(name: "Ticket Stub", description: "A movie ticket stub from last month.", category: .curious, value: 4),
        ItemDefinition(name: "Photo", description: "A blurry photo of someone's pet hamster.", category: .curious, value: 6),
        ItemDefinition(name: "Key", description: "A mysterious key. What does it unlock?", category: .curious, value: 15),
        ItemDefinition(name: "Marble", description: "A single glass marble, green with swirls.", category: .curious, value: 8),
        ItemDefinition(name: "Lottery Ticket", description: "A scratched lottery ticket. Looks like a loser.", category: .curious, value: 1),
        ItemDefinition(name: "USB Drive", description: "A tiny USB drive. Wonder what's on it?", category: .curious, value: 20),
        ItemDefinition(name: "Toy Soldier", description: "A small plastic soldier missing his rifle.", category: .curious, value: 7)
    ]
    
    /// Get a random item from the database.
    static func randomItem() -> ItemDefinition {
        allItems.randomElement() ?? allItems[0]
    }
    
    /// Get a specific number of random items without duplicates.
    static func randomItems(count: Int) -> [ItemDefinition] {
        Array(allItems.shuffled().prefix(count))
    }
    
    /// Get random items from a specific category.
    static func randomItems(from category: ItemCategory, count: Int) -> [ItemDefinition] {
        let categoryItems = allItems.filter { $0.category == category }
        return Array(categoryItems.shuffled().prefix(count))
    }
}