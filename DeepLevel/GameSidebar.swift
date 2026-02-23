import SwiftUI

/// Sidebar view displaying game state, scoring, trading, and navigation.
///
/// Shows the Dope Wars style economy information including cash, debt,
/// score, inventory, and local market prices. Provides buy/sell controls
/// and game navigation options.
///
/// - Since: 1.0.0
struct GameSidebar: View {
    @ObservedObject var economy: GameEconomy
    var onNewGame: () -> Void
    var onCycleAlgorithm: () -> Void

    var body: some View {
        List {
            scoreSection
            districtSection
            inventorySection
            marketSection
            eventsSection
            actionsSection
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .navigationTitle("DeepLevel")
    }

    // MARK: - Sections

    private var scoreSection: some View {
        Section("Score") {
            HStack {
                Label("Score", systemImage: "star.fill")
                Spacer()
                Text("\(economy.score)")
                    .fontWeight(.bold)
                    .foregroundStyle(economy.score >= 0 ? .green : .red)
            }
            HStack {
                Label("Cash", systemImage: "dollarsign.circle")
                Spacer()
                Text("$\(economy.cash)")
            }
            HStack {
                Label("Debt", systemImage: "exclamationmark.triangle")
                Spacer()
                Text("$\(economy.debt)")
                    .foregroundStyle(.red)
            }
            HStack {
                Label("HP", systemImage: "heart.fill")
                Spacer()
                Text("\(economy.hp)")
                    .foregroundStyle(.pink)
            }
            HStack {
                Label("Charmed", systemImage: "sparkles")
                Spacer()
                Text("\(economy.charmedScore)")
            }
            HStack {
                Label("Turns", systemImage: "clock")
                Spacer()
                Text("\(economy.turnsRemaining)")
            }
            HStack {
                Label("Algorithm", systemImage: "square.grid.3x3")
                Spacer()
                Text(economy.currentAlgorithm)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var districtSection: some View {
        Section("District") {
            HStack {
                Label(economy.currentDistrict.rawValue, systemImage: "mappin.and.ellipse")
                    .fontWeight(.semibold)
            }
        }
    }

    private var inventorySection: some View {
        Section("Inventory (\(economy.totalItems)/\(economy.maxInventoryCapacity))") {
            if economy.inventory.isEmpty {
                Text("No items")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(economy.inventory.sorted(by: { $0.key < $1.key }), id: \.key) { id, qty in
                    if let item = GameEconomy.tradingItems.first(where: { $0.id == id }) {
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("×\(qty)")
                                .foregroundStyle(.secondary)
                            Button("Sell") {
                                economy.sellItem(id: id)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var marketSection: some View {
        Section("Market") {
            ForEach(economy.localPrices, id: \.0.id) { item, price in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.subheadline)
                        Text(item.category.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("$\(price)")
                        .monospacedDigit()
                    Button("Buy") {
                        economy.buyItem(id: item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(economy.cash < price || economy.totalItems >= economy.maxInventoryCapacity)
                }
            }
        }
    }

    private var eventsSection: some View {
        Section("Events") {
            if economy.recentEvents.isEmpty {
                Text("No events yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(economy.recentEvents) { event in
                    HStack {
                        Circle()
                            .fill(eventColor(event.type))
                            .frame(width: 8, height: 8)
                        Text(event.message)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                economy.payDebt(amount: 50)
            } label: {
                Label("Pay Debt ($50)", systemImage: "banknote")
            }
            .disabled(economy.cash < 1 || economy.debt < 1)

            Button {
                onCycleAlgorithm()
            } label: {
                Label("Change Map", systemImage: "map")
            }

            Button {
                economy.reset()
                onNewGame()
            } label: {
                Label("New Game", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private func eventColor(_ type: GameEconomy.GameEvent.EventType) -> Color {
        switch type {
        case .info: return .blue
        case .gain: return .green
        case .loss: return .orange
        case .danger: return .red
        case .bonus: return .purple
        }
    }
}
