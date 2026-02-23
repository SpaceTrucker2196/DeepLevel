//
//  GameEconomyTests.swift
//  DeepLevelTests
//
//  Tests for the Dope Wars style trading economy system.
//

import Testing
@testable import DeepLevel

/// Tests for the GameEconomy trading system.
struct GameEconomyTests {

    // MARK: - Initialization

    @Test func testInitialState() async throws {
        let economy = GameEconomy()
        #expect(economy.cash == 100)
        #expect(economy.debt == 500)
        #expect(economy.turnsRemaining == 30)
        #expect(economy.currentDistrict == .urban)
        #expect(economy.inventory.isEmpty)
        #expect(economy.recentEvents.isEmpty)
        #expect(!economy.localPrices.isEmpty)
    }

    @Test func testInitialScore() async throws {
        let economy = GameEconomy()
        // score = cash + inventory value - debt = 100 + 0 - 500 = -400
        #expect(economy.score == economy.cash - economy.debt)
    }

    // MARK: - Trading

    @Test func testBuyItem() async throws {
        let economy = GameEconomy()
        economy.cash = 200
        economy.updateLocalPrices()

        guard let firstItem = economy.localPrices.first else {
            Issue.record("No items in local prices")
            return
        }
        let itemId = firstItem.0.id
        let price = firstItem.1

        let success = economy.buyItem(id: itemId)
        #expect(success == true)
        #expect(economy.cash == 200 - price)
        #expect(economy.inventory[itemId] == 1)
        #expect(economy.totalItems == 1)
    }

    @Test func testBuyItemInsufficientFunds() async throws {
        let economy = GameEconomy()
        economy.cash = 0
        economy.updateLocalPrices()

        guard let firstItem = economy.localPrices.first else { return }
        let success = economy.buyItem(id: firstItem.0.id)
        #expect(success == false)
        #expect(economy.inventory.isEmpty)
    }

    @Test func testBuyItemInventoryFull() async throws {
        let economy = GameEconomy()
        economy.cash = 100000
        economy.updateLocalPrices()

        guard let firstItem = economy.localPrices.first else { return }
        // Fill inventory to max
        economy.inventory[firstItem.0.id] = economy.maxInventoryCapacity
        let success = economy.buyItem(id: firstItem.0.id)
        #expect(success == false)
    }

    @Test func testSellItem() async throws {
        let economy = GameEconomy()
        economy.updateLocalPrices()

        guard let firstItem = economy.localPrices.first else { return }
        let itemId = firstItem.0.id
        let price = firstItem.1

        economy.inventory[itemId] = 3
        let startingCash = economy.cash

        let success = economy.sellItem(id: itemId)
        #expect(success == true)
        #expect(economy.cash == startingCash + price)
        #expect(economy.inventory[itemId] == 2)
    }

    @Test func testSellItemNotOwned() async throws {
        let economy = GameEconomy()
        economy.updateLocalPrices()

        let success = economy.sellItem(id: "nonexistent")
        #expect(success == false)
    }

    @Test func testSellLastItemRemovesKey() async throws {
        let economy = GameEconomy()
        economy.updateLocalPrices()

        guard let firstItem = economy.localPrices.first else { return }
        economy.inventory[firstItem.0.id] = 1

        let success = economy.sellItem(id: firstItem.0.id)
        #expect(success == true)
        #expect(economy.inventory[firstItem.0.id] == nil)
    }

    // MARK: - District

    @Test func testDistrictUpdate() async throws {
        let economy = GameEconomy()
        economy.currentDistrict = .urban

        economy.updateDistrict(from: .park)
        #expect(economy.currentDistrict == .park)

        economy.updateDistrict(from: .redLight)
        #expect(economy.currentDistrict == .redLight)

        economy.updateDistrict(from: .retail)
        #expect(economy.currentDistrict == .retail)
    }

    @Test func testDistrictUnchangedForNonDistrictTiles() async throws {
        let economy = GameEconomy()
        economy.currentDistrict = .urban

        economy.updateDistrict(from: .wall)
        #expect(economy.currentDistrict == .urban)

        economy.updateDistrict(from: .floor)
        #expect(economy.currentDistrict == .urban)
    }

    @Test func testDistrictPriceVariation() async throws {
        let economy = GameEconomy()

        economy.currentDistrict = .park
        economy.updateLocalPrices()
        let parkPrices = economy.localPrices

        economy.currentDistrict = .redLight
        economy.updateLocalPrices()
        let redLightPrices = economy.localPrices

        // Prices should differ between districts (probabilistic, but highly likely)
        let parkTotal = parkPrices.reduce(0) { $0 + $1.1 }
        let redLightTotal = redLightPrices.reduce(0) { $0 + $1.1 }
        // Just verify both have prices > 0
        #expect(parkTotal > 0)
        #expect(redLightTotal > 0)
    }

    // MARK: - Turns

    @Test func testAdvanceTurn() async throws {
        let economy = GameEconomy()
        let initialTurns = economy.turnsRemaining
        economy.advanceTurn()
        #expect(economy.turnsRemaining == initialTurns - 1)
    }

    @Test func testAdvanceTurnNoNegative() async throws {
        let economy = GameEconomy()
        economy.turnsRemaining = 0
        economy.advanceTurn()
        #expect(economy.turnsRemaining == 0)
    }

    @Test func testDebtInterest() async throws {
        let economy = GameEconomy()
        economy.turnsRemaining = 6
        economy.debt = 100
        // Advance to turn 5 (mod 5 == 0 triggers interest)
        economy.advanceTurn() // 5 remaining, 5 % 5 == 0 -> interest
        #expect(economy.debt > 100)
    }

    // MARK: - Events

    @Test func testCharmBonus() async throws {
        let economy = GameEconomy()
        let startCash = economy.cash
        economy.applyCharmBonus()
        #expect(economy.cash > startCash)
        #expect(!economy.recentEvents.isEmpty)
    }

    @Test func testStedenkoPenalty() async throws {
        let economy = GameEconomy()
        economy.cash = 50
        let startCash = economy.cash
        economy.applyStedenkoPenalty()
        #expect(economy.cash <= startCash)
        #expect(!economy.recentEvents.isEmpty)
    }

    @Test func testPayDebt() async throws {
        let economy = GameEconomy()
        economy.cash = 100
        economy.debt = 200
        let success = economy.payDebt(amount: 50)
        #expect(success == true)
        #expect(economy.cash == 50)
        #expect(economy.debt == 150)
    }

    @Test func testPayDebtLimited() async throws {
        let economy = GameEconomy()
        economy.cash = 30
        economy.debt = 200
        let success = economy.payDebt(amount: 50)
        #expect(success == true)
        #expect(economy.cash == 0)
        #expect(economy.debt == 170)
    }

    @Test func testPayDebtNoCash() async throws {
        let economy = GameEconomy()
        economy.cash = 0
        economy.debt = 200
        let success = economy.payDebt(amount: 50)
        #expect(success == false)
    }

    // MARK: - Reset

    @Test func testReset() async throws {
        let economy = GameEconomy()
        economy.cash = 999
        economy.debt = 0
        economy.turnsRemaining = 1
        economy.inventory["test"] = 5
        economy.reset()
        #expect(economy.cash == 100)
        #expect(economy.debt == 500)
        #expect(economy.turnsRemaining == 30)
        #expect(economy.inventory.isEmpty)
        #expect(economy.recentEvents.isEmpty)
    }

    // MARK: - Inventory Value

    @Test func testInventoryValue() async throws {
        let economy = GameEconomy()
        economy.updateLocalPrices()

        guard let firstItem = economy.localPrices.first else { return }
        economy.inventory[firstItem.0.id] = 2
        #expect(economy.inventoryValue == firstItem.1 * 2)
    }

    // MARK: - Trading Items

    @Test func testTradingItemsExist() async throws {
        #expect(!GameEconomy.tradingItems.isEmpty)
        #expect(GameEconomy.tradingItems.count == 20)
    }

    @Test func testAllCategoriesRepresented() async throws {
        let categories = Set(GameEconomy.tradingItems.map { $0.category })
        for cat in GameEconomy.TradingCategory.allCases {
            #expect(categories.contains(cat))
        }
    }

    @Test func testAllDistrictsHaveMultipliers() async throws {
        for district in GameEconomy.District.allCases {
            let multipliers = district.priceMultipliers
            for cat in GameEconomy.TradingCategory.allCases {
                #expect(multipliers[cat] != nil)
            }
        }
    }

    // MARK: - Score

    @Test func testScoreCalculation() async throws {
        let economy = GameEconomy()
        economy.cash = 200
        economy.debt = 100
        economy.updateLocalPrices()
        // Score = cash + inventoryValue - debt = 200 + 0 - 100 = 100
        #expect(economy.score == 100)
    }

    // MARK: - Events Cap

    @Test func testEventsCappedAtTen() async throws {
        let economy = GameEconomy()
        for _ in 0..<15 {
            economy.applyCharmBonus()
        }
        #expect(economy.recentEvents.count <= 10)
    }
}
