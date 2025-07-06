import Foundation
import Combine

// MARK: - Base ViewModel Protocol
@MainActor
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    var state: State { get set }
    func onAppear()
    func onDisappear()
}

// MARK: - Base ViewModel Implementation
@MainActor
class BaseViewModel<S>: ViewModelProtocol, ObservableObject {
    @Published var state: S
    
    let errorHandler: ErrorHandler
    internal var cancellables = Set<AnyCancellable>()
    
    init(initialState: S, errorHandler: ErrorHandler) {
        self.state = initialState
        self.errorHandler = errorHandler
    }
    
    // MARK: - Lifecycle Methods
    func onAppear() {
        // Override in subclasses for custom behavior
    }
    
    func onDisappear() {
        // Override in subclasses for custom behavior
    }
    
    // MARK: - Error Handling
    func handleError(_ error: Error, context: ErrorContext? = nil) {
        errorHandler.handle(error, context: context)
        // Subclasses should handle displaying the error message
        // This could be implemented with a common error state
    }
    
    // MARK: - Async Operations with Error Handling
    func withErrorHandling<T>(
        _ operation: String,
        block: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await block()
        } catch {
            handleError(error, context: ErrorContext(operation: operation))
            return nil
        }
    }
    
    // MARK: - Memory Management
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Loading State Mixin
protocol LoadingState {
    var isLoading: Bool { get set }
}

// MARK: - Error State Mixin
protocol ErrorState {
    var errorMessage: String? { get set }
    var hasError: Bool { get }
}

extension ErrorState {
    var hasError: Bool {
        return errorMessage != nil
    }
}