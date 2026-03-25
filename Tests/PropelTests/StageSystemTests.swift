import Foundation
@testable import Propel
import Testing

struct StageModelTests {
    @Test func boardInitializesWithDefaultStages() {
        let board = Board()

        #expect(board.stages.count == 3)
        #expect(board.stages[0].name == "Backlog")
        #expect(board.stages[0].isDefaultIntake == true)
        #expect(board.stages[0].isDoneStage == false)
        #expect(board.stages[1].name == "In Progress")
        #expect(board.stages[1].isDefaultIntake == false)
        #expect(board.stages[2].name == "Completed")
        #expect(board.stages[2].isDoneStage == true)
        #expect(board.defaultIntakeStage?.id == board.stages[0].id)
    }

    @Test func newBoardRoundTripUsesStagesAndStageId() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let board = Board(
            stages: [
                Stage(
                    name: "Inbox",
                    icon: "tray",
                    color: .slate,
                    position: 0,
                    isDefaultIntake: true
                ),
                Stage(
                    name: "Shipped",
                    icon: "shippingbox.fill",
                    color: .green,
                    position: 1,
                    isDoneStage: true
                )
            ],
            cards: [
                Card(
                    title: "Ship it",
                    stageId: UUID(),
                    label: .code,
                    createdAt: now,
                    updatedAt: now,
                    isBlocked: true
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(board)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"stages\""))
        #expect(json.contains("\"stageId\""))
        #expect(json.contains("\"isBlocked\""))
        #expect(!json.contains("\"columns\""))
        #expect(!json.contains("\"columnId\""))
    }
}

struct LabelModelTests {
    @Test func boardInitializesWithDefaultLabels() {
        let board = Board()

        #expect(board.labels.count == 6)
        #expect(board.labels.contains(where: { $0.name == "Blog Post" }))
        #expect(board.labels.contains(where: { $0.name == "Conference Talk" }))
    }

    @Test func legacyLabelStringDecodesToDefaultLabel() throws {
        let json = """
        {
          "id" : "\(UUID().uuidString)",
          "title" : "Legacy card",
          "description" : "",
          "stageId" : "\(UUID().uuidString)",
          "label" : "Video",
          "priority" : "normal",
          "checklist" : [],
          "isRecurring" : false,
          "reminder" : "none",
          "createdAt" : "2026-03-24T10:00:00Z",
          "updatedAt" : "2026-03-24T10:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let card = try decoder.decode(Card.self, from: Data(json.utf8))
        #expect(card.label.name == "Video")
        #expect(card.label.id == Label.video.id)
    }
}

struct StageMigrationTests {
    @Test func legacyBoardDecodesAndMigratesBlockedColumnToFlag() throws {
        let backlogId = UUID()
        let inProgressId = UUID()
        let blockedId = UUID()
        let completedId = UUID()
        let cardId = UUID()
        let createdAt = "2026-03-24T10:00:00Z"

        let json = """
        {
          "id" : "\(UUID().uuidString)",
          "name" : "Legacy",
          "columns" : [
            {
              "id" : "\(backlogId.uuidString)",
              "name" : "Backlog",
              "status" : "Backlog",
              "sortBy" : ["priority","dueDate"],
              "sortDirection" : "ascending",
              "position" : 0
            },
            {
              "id" : "\(inProgressId.uuidString)",
              "name" : "In Progress",
              "status" : "In Progress",
              "sortBy" : ["priority","dueDate"],
              "sortDirection" : "ascending",
              "position" : 1
            },
            {
              "id" : "\(blockedId.uuidString)",
              "name" : "Blocked",
              "status" : "Blocked",
              "sortBy" : ["priority","dueDate"],
              "sortDirection" : "ascending",
              "position" : 2
            },
            {
              "id" : "\(completedId.uuidString)",
              "name" : "Completed",
              "status" : "Completed",
              "sortBy" : ["priority","dueDate"],
              "sortDirection" : "ascending",
              "position" : 3
            }
          ],
          "cards" : [
            {
              "id" : "\(cardId.uuidString)",
              "title" : "Blocked legacy card",
              "description" : "",
              "columnId" : "\(blockedId.uuidString)",
              "label" : "Blog Post",
              "priority" : "normal",
              "checklist" : [],
              "isRecurring" : false,
              "reminder" : "none",
              "createdAt" : "\(createdAt)",
              "updatedAt" : "\(createdAt)"
            }
          ],
          "createdAt" : "\(createdAt)",
          "updatedAt" : "\(createdAt)"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let board = try decoder.decode(Board.self, from: Data(json.utf8))
        let migratedCard = try #require(board.cards.first)
        let inProgressStage = try #require(board.stages.first(where: { $0.name == "In Progress" }))

        #expect(board.stages.count == 3)
        #expect(board.stages.contains(where: { $0.name == "Backlog" && $0.isDefaultIntake }))
        #expect(board.stages.contains(where: { $0.name == "Completed" && $0.isDoneStage }))
        #expect(!board.stages.contains(where: { $0.name == "Blocked" }))
        #expect(migratedCard.stageId == inProgressStage.id)
        #expect(migratedCard.isBlocked == true)
    }
}

@MainActor
struct StageWorkflowTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func blockingKeepsCardInPlace() {
        let vm = makeViewModel()
        let activeStageId = vm.board.stages[1].id

        vm.createCard(title: "Blocked in place", label: .code, priority: .normal, inStage: activeStageId)
        let cardId = vm.board.cards[0].id

        vm.toggleCardBlocked(cardId)

        #expect(vm.board.cards[0].stageId == activeStageId)
        #expect(vm.board.cards[0].isBlocked == true)
    }

    @Test func recurringCompletionResetsToDefaultIntakeStage() throws {
        let vm = makeViewModel()
        let defaultStageId = try #require(vm.board.defaultIntakeStage?.id)
        let doneStageId = try #require(vm.board.doneStages.first?.id)

        let recurring = Card(
            title: "Recurring",
            stageId: vm.board.stages[1].id,
            label: .video,
            dueDate: Date(),
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 1, frequency: .weekly)
        )

        vm.board.cards.append(recurring)
        vm.moveCard(recurring.id, toStage: doneStageId)

        #expect(vm.board.cards.count == 2)
        #expect(vm.board.cards[0].completedAt != nil)
        #expect(vm.board.cards[0].isBlocked == false)
        #expect(vm.board.cards[1].stageId == defaultStageId)
    }

    @Test func doneStageExcludesBlockedCardFromAttentionAndCountsItAsDone() throws {
        let vm = makeViewModel()
        let doneStageId = try #require(vm.board.doneStages.first?.id)
        var card = Card(title: "Done blocked", stageId: doneStageId, label: .blogPost, isBlocked: true)
        card.completedAt = Date()
        vm.board.cards.append(card)

        #expect(vm.attentionCards.isEmpty)
        #expect(vm.doneCount == 1)
        #expect(vm.blockedCount == 0)
    }
}

@MainActor
struct LabelWorkflowTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func updatingLabelSyncsExistingCards() {
        let vm = makeViewModel()
        let label = vm.board.labels[0]
        vm.createCard(title: "Tagged", label: label, priority: .normal, inStage: vm.board.stages[0].id)

        var updatedLabel = label
        updatedLabel.name = "Essays"
        updatedLabel.color = .purple
        vm.updateLabel(updatedLabel)

        #expect(vm.board.cards[0].label.name == "Essays")
        #expect(vm.board.cards[0].label.color == .purple)
    }

    @Test func deletingLabelReassignsCardsToReplacement() {
        let vm = makeViewModel()
        let originalLabel = vm.board.labels[0]
        let replacementLabel = vm.board.labels[1]
        vm.createCard(title: "Tagged", label: originalLabel, priority: .normal, inStage: vm.board.stages[0].id)

        vm.deleteLabel(originalLabel.id, replacementLabelId: replacementLabel.id)

        #expect(vm.board.cards[0].label.id == replacementLabel.id)
        #expect(vm.board.labels.contains(where: { $0.id == replacementLabel.id }))
        #expect(!vm.board.labels.contains(where: { $0.id == originalLabel.id }))
    }

    @Test func addingLabelsCyclesThroughLeastUsedColors() {
        let vm = makeViewModel()

        let firstId = vm.addLabel()
        let secondId = vm.addLabel()

        let first = vm.board.labels.first(where: { $0.id == firstId })
        let second = vm.board.labels.first(where: { $0.id == secondId })

        #expect(first?.color == .yellow)
        #expect(second?.color == .teal)
    }
}
