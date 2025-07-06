import Foundation

// MARK: - Default DI Container Implementation
public final class DefaultDIContainer: DIContainer {
    
    // MARK: - Private Properties
    private var registrations: [String: DependencyRegistration] = [:]
    private var singletonInstances: [String: Any] = [:]
    private var resolutionStack: Set<String> = []
    
    // Thread-safe access using concurrent queue with barriers for writes
    private let queue = DispatchQueue(label: "com.sakungfujournal.di.container", attributes: .concurrent)
    
    // Parent container for hierarchical DI
    private weak var parent: DefaultDIContainer?
    
    // MARK: - Initialization
    public init(parent: DefaultDIContainer? = nil) {
        self.parent = parent
    }
    
    // MARK: - DIContainer Protocol Implementation
    
    public func register<T>(_ type: T.Type, lifecycle: DependencyLifecycle, factory: @escaping () -> T) {
        let key = String(describing: type)
        let registration = DependencyRegistration(lifecycle: lifecycle, factory: factory)
        
        queue.async(flags: .barrier) {
            self.registrations[key] = registration
            
            // Clear singleton instance if re-registering
            if lifecycle == .singleton {
                self.singletonInstances.removeValue(forKey: key)
            }
        }
    }
    
    public func resolve<T>(_ type: T.Type) throws -> T {
        let key = String(describing: type)
        
        return try queue.sync {
            // Check for circular dependencies
            if resolutionStack.contains(key) {
                throw DIError.circularDependency(key)
            }
            
            // Try to resolve from this container
            if let registration = registrations[key] {
                return try resolveWithRegistration(registration, key: key)
            }
            
            // Try to resolve from parent container
            if let parent = parent {
                return try parent.resolve(type)
            }
            
            // Type not found
            throw DIError.typeNotRegistered(key)
        }
    }
    
    public func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        
        return queue.sync {
            if registrations[key] != nil {
                return true
            }
            
            // Check parent container
            return parent?.isRegistered(type) ?? false
        }
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            self.registrations.removeAll()
            self.singletonInstances.removeAll()
            self.resolutionStack.removeAll()
        }
    }
    
    public func createChild() -> DIContainer {
        return DefaultDIContainer(parent: self)
    }
    
    // MARK: - Private Resolution Methods
    
    private func resolveWithRegistration<T>(_ registration: DependencyRegistration, key: String) throws -> T {
        switch registration.lifecycle {
        case .singleton:
            return try resolveSingleton(registration, key: key)
        case .transient:
            return try resolveTransient(registration, key: key)
        case .scoped:
            // For now, treat scoped as transient - can be enhanced later
            return try resolveTransient(registration, key: key)
        }
    }
    
    private func resolveSingleton<T>(_ registration: DependencyRegistration, key: String) throws -> T {
        // Check if singleton instance already exists
        if let existingInstance = singletonInstances[key] as? T {
            return existingInstance
        }
        
        // Create new singleton instance
        let instance: T = try resolveTransient(registration, key: key)
        singletonInstances[key] = instance
        return instance
    }
    
    private func resolveTransient<T>(_ registration: DependencyRegistration, key: String) throws -> T {
        // Add to resolution stack to detect circular dependencies
        resolutionStack.insert(key)
        
        defer {
            resolutionStack.remove(key)
        }
        
        do {
            let instance = registration.factory()
            guard let typedInstance = instance as? T else {
                throw DIError.resolutionFailed(key, underlying: DIContainerError.typeMismatch)
            }
            return typedInstance
        } catch {
            throw DIError.resolutionFailed(key, underlying: error)
        }
    }
}

// MARK: - Internal Container Errors
private enum DIContainerError: Error, LocalizedError {
    case typeMismatch
    
    var errorDescription: String? {
        switch self {
        case .typeMismatch:
            return "Factory returned an instance that doesn't match the expected type"
        }
    }
}

// MARK: - Container Debug Extensions
extension DefaultDIContainer {
    /// Get debug information about registered types
    public var debugInfo: [String: String] {
        return queue.sync {
            var info: [String: String] = [:]
            
            for (key, registration) in registrations {
                let lifecycleString = String(describing: registration.lifecycle)
                let hasSingleton = singletonInstances[key] != nil
                info[key] = "\(lifecycleString)\(hasSingleton ? " (instantiated)" : "")"
            }
            
            return info
        }
    }
    
    /// Print debug information to console
    public func printDebugInfo() {
        print("🔍 DI Container Debug Info:")
        for (type, info) in debugInfo.sorted(by: { $0.key < $1.key }) {
            print("  • \(type): \(info)")
        }
        
        if let parent = parent {
            print("📦 Parent Container:")
            parent.printDebugInfo()
        }
    }
}

// MARK: - Convenience Registration Methods
extension DefaultDIContainer {
    /// Register a concrete type as both interface and implementation
    public func registerConcrete<T>(_ type: T.Type, lifecycle: DependencyLifecycle = .singleton) where T: AnyObject {
        register(type, lifecycle: lifecycle) {
            // This would require reflection or a default initializer
            // For now, this is a placeholder for future enhancement
            fatalError("Concrete type registration requires a factory closure")
        }
    }
    
    /// Register an instance directly (always singleton lifecycle)
    public func registerInstance<T>(_ instance: T, for type: T.Type) {
        register(type, lifecycle: .singleton) { instance }
    }
}