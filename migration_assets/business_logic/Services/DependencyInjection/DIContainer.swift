import Foundation

// MARK: - Dependency Lifecycle
public enum DependencyLifecycle {
    case singleton    // Single instance shared across the app
    case transient    // New instance every time
    case scoped       // Single instance per scope (e.g., per view)
}

// MARK: - Dependency Registration
public struct DependencyRegistration {
    let lifecycle: DependencyLifecycle
    let factory: () -> Any
    
    init<T>(lifecycle: DependencyLifecycle, factory: @escaping () -> T) {
        self.lifecycle = lifecycle
        self.factory = factory
    }
}

// MARK: - DI Container Protocol
public protocol DIContainer {
    /// Register a dependency with the container
    /// - Parameters:
    ///   - type: The type to register
    ///   - lifecycle: The lifecycle management strategy
    ///   - factory: Factory closure to create instances
    func register<T>(_ type: T.Type, lifecycle: DependencyLifecycle, factory: @escaping () -> T)
    
    /// Register a dependency with singleton lifecycle (convenience method)
    /// - Parameters:
    ///   - type: The type to register
    ///   - factory: Factory closure to create instances
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T)
    
    /// Register a dependency with transient lifecycle (convenience method)
    /// - Parameters:
    ///   - type: The type to register
    ///   - factory: Factory closure to create instances
    func registerTransient<T>(_ type: T.Type, factory: @escaping () -> T)
    
    /// Register an instance directly (convenience method)
    /// - Parameters:
    ///   - instance: The instance to register
    ///   - type: The type to register the instance for
    func registerInstance<T>(_ instance: T, for type: T.Type)
    
    /// Resolve a dependency from the container
    /// - Parameter type: The type to resolve
    /// - Returns: An instance of the requested type
    /// - Throws: DIError if the type is not registered or cannot be resolved
    func resolve<T>(_ type: T.Type) throws -> T
    
    /// Check if a type is registered in the container
    /// - Parameter type: The type to check
    /// - Returns: True if the type is registered, false otherwise
    func isRegistered<T>(_ type: T.Type) -> Bool
    
    /// Clear all registrations (useful for testing)
    func clear()
    
    /// Create a child container that inherits from this container
    /// - Returns: A new child container
    func createChild() -> DIContainer
}

// MARK: - DI Errors
public enum DIError: Error, LocalizedError {
    case typeNotRegistered(String)
    case resolutionFailed(String, underlying: Error)
    case circularDependency(String)
    
    public var errorDescription: String? {
        switch self {
        case .typeNotRegistered(let typeName):
            return "Type '\(typeName)' is not registered in the DI container"
        case .resolutionFailed(let typeName, let underlying):
            return "Failed to resolve type '\(typeName)': \(underlying.localizedDescription)"
        case .circularDependency(let typeName):
            return "Circular dependency detected while resolving '\(typeName)'"
        }
    }
}

// MARK: - Container Extensions
public extension DIContainer {
    /// Convenience method to register singleton dependencies
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        register(type, lifecycle: .singleton, factory: factory)
    }
    
    /// Convenience method to register transient dependencies
    func registerTransient<T>(_ type: T.Type, factory: @escaping () -> T) {
        register(type, lifecycle: .transient, factory: factory)
    }
    
    /// Convenience method to register an instance directly
    func registerInstance<T>(_ instance: T, for type: T.Type) {
        register(type, lifecycle: .singleton) { instance }
    }
    
    /// Convenience method to resolve with better error messages
    func resolve<T>(_ type: T.Type, file: String = #file, line: Int = #line) throws -> T {
        do {
            return try resolve(type)
        } catch {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            print("🔴 DI Resolution failed at \(fileName):\(line) for type \(T.self)")
            throw error
        }
    }
}