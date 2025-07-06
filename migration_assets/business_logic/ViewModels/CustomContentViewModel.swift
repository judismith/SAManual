import Foundation
import Combine

class CustomContentViewModel: ObservableObject {
    @Published var customContent: [CustomContent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataService = DataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func fetchCustomContent(for uid: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedContent = try await dataService.fetchCustomContent(for: uid)
                await MainActor.run {
                    self.customContent = fetchedContent
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func saveCustomContent(_ content: CustomContent) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await dataService.saveCustomContent(content)
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = nil
                }
                // Refresh content after saving
                await fetchCustomContent(for: content.uid)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchCustomContent(for uid: String) async {
        do {
            let fetchedContent = try await dataService.fetchCustomContent(for: uid)
            await MainActor.run {
                self.customContent = fetchedContent
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
} 