import Foundation
import Combine

@MainActor
class SubscriptionViewModel: BaseViewModel<SubscriptionState> {
    
    // MARK: - Dependencies
    private let subscriptionService: SubscriptionService
    private let userService: UserService
    
    // MARK: - Initialization
    init(
        subscriptionService: SubscriptionService,
        userService: UserService,
        errorHandler: ErrorHandler
    ) {
        self.subscriptionService = subscriptionService
        self.userService = userService
        
        super.init(
            initialState: SubscriptionState(),
            errorHandler: errorHandler
        )
        
        setupObservers()
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Monitor subscription service for subscription updates
        subscriptionService.subscriptionUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subscription in
                self?.state.currentSubscription = subscription
            }
            .store(in: &cancellables)
        
        // Monitor subscription service for membership updates
        subscriptionService.membershipUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] membership in
                self?.state.studioMembership = membership
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func loadUserSubscriptionData(userId: String) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                // Load current subscription
                if let subscription = try await subscriptionService.getCurrentSubscription(for: userId) {
                    state.currentSubscription = subscription
                }
                
                // Load studio membership
                if let membership = try await subscriptionService.getStudioMembership(for: userId) {
                    state.studioMembership = membership
                }
                
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func fetchSubscriptionPlans() {
        state.isLoading = true
        state.errorMessage = nil
        
        // Note: This would need to be implemented in the subscription service
        // For now, we'll use mock data
        Task {
            // Simulate fetching subscription plans
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let mockPlans = [
                Subscription(
                    id: "basic-monthly",
                    name: "Basic Monthly",
                    price: 9.99,
                    billingCycle: .monthly,
                    features: [.unlimitedAccess]
                ),
                Subscription(
                    id: "premium-monthly",
                    name: "Premium Monthly", 
                    price: 19.99,
                    billingCycle: .monthly,
                    features: [.unlimitedAccess, .premiumContent, .offlineDownloads]
                ),
                Subscription(
                    id: "premium-yearly",
                    name: "Premium Yearly",
                    price: 199.99,
                    billingCycle: .yearly,
                    features: [.unlimitedAccess, .premiumContent, .offlineDownloads, .personalizedRecommendations]
                )
            ]
            
            state.subscriptionPlans = mockPlans
            state.isLoading = false
        }
    }
    
    func createSubscription(_ subscription: UserSubscription) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let createdSubscription = try await subscriptionService.createSubscription(subscription)
                state.currentSubscription = createdSubscription
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func updateSubscription(_ subscription: UserSubscription) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let updatedSubscription = try await subscriptionService.updateSubscription(subscription)
                state.currentSubscription = updatedSubscription
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func updateStudioMembership(_ membership: StudioMembership) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let updatedMembership = try await subscriptionService.updateStudioMembership(membership)
                state.studioMembership = updatedMembership
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func cancelSubscription() {
        guard let subscription = state.currentSubscription else {
            state.errorMessage = "No active subscription to cancel"
            return
        }
        
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                try await subscriptionService.cancelSubscription(for: subscription.userId)
                
                // The subscription service should publish the updated subscription
                // through subscriptionUpdatesPublisher
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func renewSubscription() {
        guard let subscription = state.currentSubscription else {
            state.errorMessage = "No subscription to renew"
            return
        }
        
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let renewedSubscription = try await subscriptionService.renewSubscription(for: subscription.userId)
                state.currentSubscription = renewedSubscription
                state.isLoading = false
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func refreshMembershipStatus() {
        guard let membership = state.studioMembership else {
            return
        }
        
        Task {
            do {
                let refreshedMembership = try await subscriptionService.refreshMembershipStatus(for: membership.userId)
                state.studioMembership = refreshedMembership
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func checkAccess(to content: AccessibleContent) async -> Bool {
        guard let currentUser = try? await userService.getCurrentUser() else {
            return false
        }
        
        do {
            return try await subscriptionService.hasAccess(userId: currentUser.id, to: content)
        } catch {
            return false
        }
    }
    
    func validateSubscriptionAccess(programId: String) async -> Bool {
        guard let currentUser = try? await userService.getCurrentUser() else {
            return false
        }
        
        do {
            return try await subscriptionService.validateSubscriptionAccess(userId: currentUser.id, programId: programId)
        } catch {
            return false
        }
    }
    
    func getBillingHistory() {
        guard let subscription = state.currentSubscription else {
            state.errorMessage = "No subscription found"
            return
        }
        
        Task {
            do {
                let billingHistory = try await subscriptionService.getBillingHistory(for: subscription.userId)
                state.billingHistory = billingHistory
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func getNextBillingDate() async -> Date? {
        guard let subscription = state.currentSubscription else {
            return nil
        }
        
        do {
            return try await subscriptionService.getNextBillingDate(for: subscription.userId)
        } catch {
            return nil
        }
    }
    
    func updatePaymentMethod(_ paymentMethod: PaymentMethod) {
        guard let subscription = state.currentSubscription else {
            state.errorMessage = "No subscription found"
            return
        }
        
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                try await subscriptionService.updatePaymentMethod(for: subscription.userId, paymentMethod: paymentMethod)
                state.isLoading = false
                
                // Refresh subscription to get updated payment method
                loadUserSubscriptionData(userId: subscription.userId)
                
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    // MARK: - Computed Properties
    func getSubscriptionStatus() -> String {
        guard let subscription = state.currentSubscription else {
            return "No Active Subscription"
        }
        
        if subscription.isActive {
            return "Active - \(subscription.type.displayName)"
        } else {
            return "\(subscription.status.displayName) - \(subscription.type.displayName)"
        }
    }
    
    func getStudioMembershipStatus() -> String {
        guard let membership = state.studioMembership else {
            return "No Studio Membership"
        }
        
        if membership.isActive {
            return "Active - \(membership.membershipType.rawValue) (\(String(format: "%.0f", membership.discountPercentage))% discount)"
        } else {
            return "Inactive - \(membership.membershipType.rawValue)"
        }
    }
    
    func hasActiveSubscription() -> Bool {
        return state.currentSubscription?.isActive == true
    }
    
    func hasStudioMembership() -> Bool {
        return state.studioMembership?.isActive == true
    }
    
    func getDiscountPercentage() -> Double {
        return state.studioMembership?.discountPercentage ?? 0.0
    }
    
    func getAccessLevel() async -> AccessLevel {
        guard let currentUser = try? await userService.getCurrentUser() else {
            return .free
        }
        
        do {
            return try await subscriptionService.getAccessLevel(for: currentUser.id)
        } catch {
            return .free
        }
    }
}

// MARK: - Subscription State
struct SubscriptionState {
    var subscriptionPlans: [Subscription] = []
    var currentSubscription: UserSubscription?
    var studioMembership: StudioMembership?
    var billingHistory: [BillingRecord] = []
    var isLoading: Bool = false
    var errorMessage: String?
}

// MARK: - Supporting Types
struct Subscription {
    let id: String
    let name: String
    let price: Double
    let billingCycle: BillingCycle
    let features: [SubscriptionFeature]
}