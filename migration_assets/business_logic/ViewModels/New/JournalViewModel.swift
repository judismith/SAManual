import Foundation
import Combine
import SwiftUI

@MainActor
class JournalViewModel: BaseViewModel<JournalState> {
    
    // MARK: - Dependencies
    private let journalService: JournalService
    private let userService: UserService
    private let programService: ProgramService
    
    // MARK: - Initialization
    init(
        journalService: JournalService,
        userService: UserService,
        programService: ProgramService,
        errorHandler: ErrorHandler
    ) {
        self.journalService = journalService
        self.userService = userService
        self.programService = programService
        
        super.init(
            initialState: JournalState(),
            errorHandler: errorHandler
        )
        
        setupObservers()
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Monitor journal service for entry updates
        journalService.journalUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedEntry in
                self?.handleJournalUpdate(updatedEntry)
            }
            .store(in: &cancellables)
    }
    
    private func handleJournalUpdate(_ entry: JournalEntry) {
        // Update or add the entry in the local array
        if let index = state.entries.firstIndex(where: { $0.id == entry.id }) {
            state.entries[index] = entry
        } else {
            state.entries.append(entry)
        }
        
        // Re-sort entries by timestamp
        state.entries.sort { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Public Methods
    func loadJournalEntries(for userId: String) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let fetchedEntries = try await journalService.getEntries(for: userId)
                state.entries = fetchedEntries.sorted { $0.timestamp > $1.timestamp }
                state.isLoading = false
                state.errorMessage = nil
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func createJournalEntry(
        title: String,
        content: String,
        personalNotes: String = "",
        practiceNotes: String = "",
        difficultyRating: Int = 3,
        needsPractice: Bool = false,
        referencedContent: [ContentReference] = [],
        tags: [String] = [],
        mediaUrls: [String] = [],
        userId: String
    ) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                // Map from old JournalEntry structure to new structure
                let entry = JournalEntry(
                    userId: userId,
                    timestamp: Date(),
                    content: "\(title)\n\n\(content)\n\nPersonal Notes: \(personalNotes)\n\nPractice Notes: \(practiceNotes)",
                    difficultyRating: difficultyRating,
                    needsPractice: needsPractice,
                    referencedContent: referencedContent,
                    mood: nil, // Could be enhanced to map from difficulty rating
                    tags: tags
                )
                
                let savedEntry = try await journalService.saveEntry(entry)
                
                // Track analytics for referenced content using program service
                for reference in referencedContent {
                    await trackContentReference(contentId: reference.id, type: reference.type)
                }
                
                // Reload entries to include the new one
                loadJournalEntries(for: userId)
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func deleteJournalEntry(_ entry: JournalEntry) {
        state.isLoading = true
        
        Task {
            do {
                try await journalService.deleteEntry(id: entry.id)
                
                // Remove from local array
                state.entries.removeAll { $0.id == entry.id }
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func updateJournalEntry(_ entry: JournalEntry) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let updatedEntry = try await journalService.updateEntry(entry)
                
                // Update the entry in the local array
                if let index = state.entries.firstIndex(where: { $0.id == entry.id }) {
                    state.entries[index] = updatedEntry
                    // Re-sort entries by timestamp
                    state.entries.sort { $0.timestamp > $1.timestamp }
                }
                
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func searchEntries(query: String, userId: String) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let searchResults = try await journalService.searchEntries(for: userId, query: query)
                state.entries = searchResults.sorted { $0.timestamp > $1.timestamp }
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func getEntriesForContent(userId: String, contentId: String, contentType: ContentType) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let filteredEntries = try await journalService.getEntriesForContent(
                    userId: userId,
                    contentId: contentId,
                    contentType: contentType
                )
                state.entries = filteredEntries.sorted { $0.timestamp > $1.timestamp }
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func getEntriesInDateRange(userId: String, from: Date, to: Date) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let dateFilteredEntries = try await journalService.getEntriesInDateRange(
                    for: userId,
                    from: from,
                    to: to
                )
                state.entries = dateFilteredEntries.sorted { $0.timestamp > $1.timestamp }
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func getEntryAnalytics(userId: String) {
        Task {
            do {
                let entryCount = try await journalService.getEntryCount(for: userId)
                let avgDifficulty = try await journalService.getAverageDifficultyRating(for: userId)
                let entriesNeedingPractice = try await journalService.getEntriesNeedingPractice(for: userId)
                
                state.analytics = JournalAnalytics(
                    totalEntries: entryCount,
                    averageDifficulty: avgDifficulty,
                    entriesNeedingPractice: entriesNeedingPractice.count
                )
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    // MARK: - Helper Methods
    func createContentReferences(from content: [Any]) -> [ContentReference] {
        var references: [ContentReference] = []
        
        for item in content {
            if let program = item as? Program {
                references.append(ContentReference(
                    id: program.id,
                    type: .program,
                    cachedName: program.name,
                    cachedRank: nil, // Programs don't have ranks
                    cachedDescription: program.description
                ))
            } else if let technique = item as? Technique {
                references.append(ContentReference(
                    id: technique.id,
                    type: .technique,
                    cachedName: technique.name,
                    cachedRank: nil, // Will need to look up from curriculum item
                    cachedDescription: technique.description
                ))
            } else if let form = item as? Form {
                references.append(ContentReference(
                    id: form.id,
                    type: .form,
                    cachedName: form.name,
                    cachedRank: nil, // Will need to look up from curriculum item
                    cachedDescription: form.description
                ))
            } else if let announcement = item as? MediaContent {
                references.append(ContentReference(
                    id: announcement.id,
                    type: .announcement,
                    cachedName: announcement.title,
                    cachedDescription: announcement.description
                ))
            }
        }
        
        return references
    }
    
    func canAccessContent(_ reference: ContentReference) async -> Bool {
        // Use the subscription service to check access through the user service
        do {
            if let currentUser = try await userService.getCurrentUser() {
                // For now, assume access based on subscription
                // Check access level instead of subscription
                return currentUser.accessLevel != .free
            }
            return false
        } catch {
            return false
        }
    }
    
    func getContentDisplay(for reference: ContentReference) async -> ContentDisplay {
        // Try to get fresh content from program service
        do {
            switch reference.type {
            case .program:
                if let program = try await programService.getProgram(id: reference.id) {
                    return ContentDisplay(
                        id: program.id,
                        name: program.name,
                        description: program.description,
                        isAvailable: true
                    )
                }
            case .technique:
                if let technique = try await programService.getTechnique(id: reference.id) {
                    return ContentDisplay(
                        id: technique.id,
                        name: technique.name,
                        description: technique.description,
                        isAvailable: true
                    )
                }
            default:
                break
            }
        } catch {
            // Fall back to cached data
        }
        
        // Return cached data with availability flag
        return ContentDisplay(
            id: reference.id,
            name: reference.cachedName ?? "Unknown Content",
            description: reference.cachedDescription ?? "",
            isAvailable: false
        )
    }
    
    // MARK: - Private Helper Methods
    private func trackContentReference(contentId: String, type: ContentType) async {
        // Track analytics through program service or user service
        // This could be enhanced with proper analytics tracking
        print("📊 Tracking content reference: \(contentId) of type \(type)")
    }
}

// MARK: - Journal State
struct JournalState {
    var entries: [JournalEntry] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var analytics: JournalAnalytics?
}

// MARK: - Supporting Types
struct ContentDisplay {
    let id: String
    let name: String
    let description: String
    let isAvailable: Bool
}

struct JournalAnalytics {
    let totalEntries: Int
    let averageDifficulty: Double
    let entriesNeedingPractice: Int
}