import Foundation
import Combine

class LockedCurriculumViewModel: ObservableObject {
    @Published var lockedContent: [LockedContentItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firestoreService = FirestoreService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func fetchLockedContent() {
        isLoading = true
        errorMessage = nil
        
        firestoreService.fetchPrograms { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let programs):
                    self?.processLockedContent(from: programs)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func processLockedContent(from programs: [Program]) {
        var lockedItems: [LockedContentItem] = []
        
        for program in programs {
            // Add some forms that are member-only
            let forms = program.curriculum.filter { $0.type == .form }
            lockedItems.append(contentsOf: forms.prefix(3).map { LockedContentItem(title: $0.name, type: "form") })
            
            // Add some techniques that are member-only
            let techniques = program.curriculum.filter { $0.type == .technique }
            lockedItems.append(contentsOf: techniques.prefix(3).map { LockedContentItem(title: $0.name, type: "technique") })
        }
        
        self.lockedContent = Array(lockedItems.prefix(6)) // Limit to 6 items for preview
    }
}

struct LockedContentItem: Identifiable {
    let id = UUID()
    let title: String
    let type: String
} 
