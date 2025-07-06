import Foundation
import Combine

// MARK: - Mock Journal Service
public final class MockJournalService: JournalService {
    
    // MARK: - Publishers
    private let journalUpdatesSubject = PassthroughSubject<JournalEntry, Never>()
    public var journalUpdatesPublisher: AnyPublisher<JournalEntry, Never> {
        journalUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Mock Data Storage
    private var entries: [String: JournalEntry] = [:]
    private let queue = DispatchQueue(label: "MockJournalService", attributes: .concurrent)
    
    public init() {
        // Pre-populate with some mock entries
        setupMockData()
    }
    
    // MARK: - Entry Management
    public func getEntries(for userId: String) async throws -> [JournalEntry] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let userEntries = self.entries.values.filter { $0.userId == userId }
                    .sorted { $0.timestamp > $1.timestamp }
                continuation.resume(returning: userEntries)
            }
        }
    }
    
    public func getEntry(id: String) async throws -> JournalEntry? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.entries[id])
            }
        }
    }
    
    public func saveEntry(_ entry: JournalEntry) async throws -> JournalEntry {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.entries[entry.id] = entry
                self.journalUpdatesSubject.send(entry)
                continuation.resume(returning: entry)
            }
        }
    }
    
    public func updateEntry(_ entry: JournalEntry) async throws -> JournalEntry {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                guard self.entries[entry.id] != nil else {
                    continuation.resume(throwing: JournalServiceError.entryNotFound(id: entry.id))
                    return
                }
                
                self.entries[entry.id] = entry
                self.journalUpdatesSubject.send(entry)
                continuation.resume(returning: entry)
            }
        }
    }
    
    public func deleteEntry(id: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                guard self.entries[id] != nil else {
                    continuation.resume(throwing: JournalServiceError.entryNotFound(id: id))
                    return
                }
                
                self.entries.removeValue(forKey: id)
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Search and Filter
    public func searchEntries(for userId: String, query: String) async throws -> [JournalEntry] {
        let allEntries = try await getEntries(for: userId)
        return allEntries.filter { entry in
            entry.content.localizedCaseInsensitiveContains(query) ||
            entry.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    public func getEntriesForContent(userId: String, contentId: String, contentType: ContentType) async throws -> [JournalEntry] {
        let allEntries = try await getEntries(for: userId)
        return allEntries.filter { entry in
            entry.referencedContent.contains { ref in
                ref.id == contentId && ref.type == contentType
            }
        }
    }
    
    public func getEntriesInDateRange(for userId: String, from: Date, to: Date) async throws -> [JournalEntry] {
        let allEntries = try await getEntries(for: userId)
        return allEntries.filter { entry in
            entry.timestamp >= from && entry.timestamp <= to
        }
    }
    
    // MARK: - Analytics
    public func getEntryCount(for userId: String) async throws -> Int {
        let entries = try await getEntries(for: userId)
        return entries.count
    }
    
    public func getAverageDifficultyRating(for userId: String) async throws -> Double {
        let entries = try await getEntries(for: userId)
        guard !entries.isEmpty else { return 0.0 }
        
        let total = entries.reduce(0) { $0 + $1.difficultyRating }
        return Double(total) / Double(entries.count)
    }
    
    public func getEntriesNeedingPractice(for userId: String) async throws -> [JournalEntry] {
        let allEntries = try await getEntries(for: userId)
        return allEntries.filter { $0.needsPractice }
    }
    
    // MARK: - Mock Data Setup
    private func setupMockData() {
        let mockUserId = "mock-user-123"
        
        let entries = [
            JournalEntry(
                userId: mockUserId,
                timestamp: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                content: "Practiced the Tiger form today. Feeling more confident with the transitions between moves. Need to work on the final sequence though.",
                difficultyRating: 3,
                needsPractice: true,
                referencedContent: [
                    ContentReference(
                        id: "tiger-form-1",
                        type: .form,
                        cachedName: "Tiger Form",
                        cachedRank: "Yellow Belt"
                    )
                ],
                mood: .confident,
                tags: ["tiger", "forms", "yellow-belt"]
            ),
            
            JournalEntry(
                userId: mockUserId,
                timestamp: Date().addingTimeInterval(-86400 * 1), // 1 day ago
                content: "Great sparring session! Managed to successfully execute the side kick technique we've been practicing. Felt really focused today.",
                difficultyRating: 2,
                needsPractice: false,
                referencedContent: [
                    ContentReference(
                        id: "side-kick-1",
                        type: .technique,
                        cachedName: "Side Kick",
                        cachedRank: "Orange Belt"
                    )
                ],
                mood: .accomplished,
                tags: ["sparring", "kicks", "orange-belt"]
            ),
            
            JournalEntry(
                userId: mockUserId,
                timestamp: Date(), // Today
                content: "Started learning the Dragon form. Very challenging! The flowing movements are quite different from what I'm used to.",
                difficultyRating: 5,
                needsPractice: true,
                referencedContent: [
                    ContentReference(
                        id: "dragon-form-1",
                        type: .form,
                        cachedName: "Dragon Form",
                        cachedRank: "Green Belt"
                    )
                ],
                mood: .challenged,
                tags: ["dragon", "forms", "green-belt", "difficult"]
            )
        ]
        
        for entry in entries {
            self.entries[entry.id] = entry
        }
    }
}