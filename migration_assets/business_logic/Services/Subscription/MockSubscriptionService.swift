import Foundation
import Combine

// MARK: - Mock Subscription Service
public final class MockSubscriptionService: SubscriptionService {
    
    // MARK: - Publishers
    private let subscriptionUpdatesSubject = PassthroughSubject<UserSubscription, Never>()
    private let membershipUpdatesSubject = PassthroughSubject<StudioMembership?, Never>()
    
    public var subscriptionUpdatesPublisher: AnyPublisher<UserSubscription, Never> {
        subscriptionUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var membershipUpdatesPublisher: AnyPublisher<StudioMembership?, Never> {
        membershipUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Mock Data Storage
    private var subscriptions: [String: UserSubscription] = [:]
    private var memberships: [String: StudioMembership] = [:]
    private var billingRecords: [String: [BillingRecord]] = [:]
    private let queue = DispatchQueue(label: "MockSubscriptionService", attributes: .concurrent)
    
    public init() {
        setupMockData()
    }
    
    // MARK: - Subscription Management
    public func getCurrentSubscription(for userId: String) async throws -> UserSubscription? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.subscriptions[userId])
            }
        }
    }
    
    public func createSubscription(_ subscription: UserSubscription) async throws -> UserSubscription {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.subscriptions[subscription.userId] = subscription
                self.subscriptionUpdatesSubject.send(subscription)
                continuation.resume(returning: subscription)
            }
        }
    }
    
    public func updateSubscription(_ subscription: UserSubscription) async throws -> UserSubscription {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.subscriptions[subscription.userId] = subscription
                self.subscriptionUpdatesSubject.send(subscription)
                continuation.resume(returning: subscription)
            }
        }
    }
    
    public func cancelSubscription(for userId: String) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                if var subscription = self.subscriptions[userId] {
                    let cancelledSubscription = UserSubscription(
                        id: subscription.id,
                        userId: subscription.userId,
                        type: subscription.type,
                        status: .cancelled,
                        startDate: subscription.startDate,
                        endDate: subscription.endDate,
                        isActive: false,
                        autoRenew: false,
                        paymentMethod: subscription.paymentMethod,
                        billingCycle: subscription.billingCycle,
                        price: subscription.price,
                        features: subscription.features,
                        metadata: subscription.metadata
                    )
                    
                    self.subscriptions[userId] = cancelledSubscription
                    self.subscriptionUpdatesSubject.send(cancelledSubscription)
                }
                continuation.resume()
            }
        }
    }
    
    public func renewSubscription(for userId: String) async throws -> UserSubscription {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                guard let subscription = self.subscriptions[userId] else {
                    continuation.resume(throwing: SubscriptionServiceError.subscriptionNotFound(userId: userId))
                    return
                }
                
                let renewedSubscription = UserSubscription(
                    id: subscription.id,
                    userId: subscription.userId,
                    type: subscription.type,
                    status: .active,
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .month, value: subscription.billingCycle.durationInMonths, to: Date()),
                    isActive: true,
                    autoRenew: subscription.autoRenew,
                    paymentMethod: subscription.paymentMethod,
                    billingCycle: subscription.billingCycle,
                    price: subscription.price,
                    features: subscription.features,
                    metadata: subscription.metadata
                )
                
                self.subscriptions[userId] = renewedSubscription
                self.subscriptionUpdatesSubject.send(renewedSubscription)
                continuation.resume(returning: renewedSubscription)
            }
        }
    }
    
    // MARK: - Studio Membership Management
    public func getStudioMembership(for userId: String) async throws -> StudioMembership? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.memberships[userId])
            }
        }
    }
    
    public func updateStudioMembership(_ membership: StudioMembership) async throws -> StudioMembership {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.memberships[membership.userId] = membership
                self.membershipUpdatesSubject.send(membership)
                continuation.resume(returning: membership)
            }
        }
    }
    
    public func refreshMembershipStatus(for userId: String) async throws -> StudioMembership? {
        // Simulate API call delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return await withCheckedContinuation { continuation in
            queue.async {
                let membership = self.memberships[userId]
                if let membership = membership {
                    self.membershipUpdatesSubject.send(membership)
                }
                continuation.resume(returning: membership)
            }
        }
    }
    
    // MARK: - Access Level Management
    public func getAccessLevel(for userId: String) async throws -> AccessLevel {
        if let subscription = try await getCurrentSubscription(for: userId), subscription.isActive {
            return subscription.type.accessLevel
        }
        
        if let membership = try await getStudioMembership(for: userId), membership.isActive {
            return .subscriber
        }
        
        return .free
    }
    
    public func hasAccess(userId: String, to content: AccessibleContent) async throws -> Bool {
        let userAccessLevel = try await getAccessLevel(for: userId)
        
        switch content.accessLevel {
        case .public:
            return true
        case .authenticated:
            return userAccessLevel != .free
        case .restricted:
            return userAccessLevel == .subscriber || userAccessLevel == .instructor || userAccessLevel == .admin
        case .private:
            return userAccessLevel == .instructor || userAccessLevel == .admin
        }
    }
    
    public func validateSubscriptionAccess(userId: String, programId: String) async throws -> Bool {
        let subscription = try await getCurrentSubscription(for: userId)
        return subscription?.isActive ?? false
    }
    
    // MARK: - Billing and Payments
    public func getBillingHistory(for userId: String) async throws -> [BillingRecord] {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.billingRecords[userId] ?? [])
            }
        }
    }
    
    public func getNextBillingDate(for userId: String) async throws -> Date? {
        guard let subscription = try await getCurrentSubscription(for: userId),
              subscription.isActive else {
            return nil
        }
        
        return subscription.endDate
    }
    
    public func updatePaymentMethod(for userId: String, paymentMethod: PaymentMethod) async throws {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                if var subscription = self.subscriptions[userId] {
                    let updatedSubscription = UserSubscription(
                        id: subscription.id,
                        userId: subscription.userId,
                        type: subscription.type,
                        status: subscription.status,
                        startDate: subscription.startDate,
                        endDate: subscription.endDate,
                        isActive: subscription.isActive,
                        autoRenew: subscription.autoRenew,
                        paymentMethod: paymentMethod,
                        billingCycle: subscription.billingCycle,
                        price: subscription.price,
                        features: subscription.features,
                        metadata: subscription.metadata
                    )
                    
                    self.subscriptions[userId] = updatedSubscription
                    self.subscriptionUpdatesSubject.send(updatedSubscription)
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Mock Data Setup
    private func setupMockData() {
        let mockUserId = "mock-user-123"
        
        // Mock subscription
        let mockSubscription = UserSubscription(
            userId: mockUserId,
            type: .premium,
            status: .active,
            startDate: Date().addingTimeInterval(-86400 * 30), // 30 days ago
            endDate: Date().addingTimeInterval(86400 * 335), // ~11 months from now
            isActive: true,
            autoRenew: true,
            paymentMethod: PaymentMethod(
                type: .creditCard,
                last4: "4242",
                expiryMonth: 12,
                expiryYear: 2025,
                brand: "Visa",
                isDefault: true
            ),
            billingCycle: .yearly,
            price: SubscriptionPrice(amount: 99.99),
            features: [.unlimitedAccess, .premiumContent, .offlineDownloads, .personalizedRecommendations]
        )
        
        subscriptions[mockUserId] = mockSubscription
        
        // Mock studio membership
        let mockMembership = StudioMembership(
            userId: mockUserId,
            studioId: "studio-123",
            studioName: "Elite Martial Arts Studio",
            membershipType: .student,
            status: .active,
            joinDate: Date().addingTimeInterval(-86400 * 60), // 60 days ago
            isActive: true,
            benefits: [.discountedSubscription, .exclusiveContent, .priorityBooking],
            discountPercentage: 15.0
        )
        
        memberships[mockUserId] = mockMembership
        
        // Mock billing history
        let mockBillingRecords = [
            BillingRecord(
                userId: mockUserId,
                amount: 99.99,
                date: Date().addingTimeInterval(-86400 * 30),
                status: .paid,
                description: "Premium Annual Subscription"
            ),
            BillingRecord(
                userId: mockUserId,
                amount: 9.99,
                date: Date().addingTimeInterval(-86400 * 60),
                status: .paid,
                description: "Premium Monthly Subscription (before upgrade)"
            )
        ]
        
        billingRecords[mockUserId] = mockBillingRecords
    }
}