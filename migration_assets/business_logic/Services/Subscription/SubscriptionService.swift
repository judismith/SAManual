import Foundation
import Combine

// MARK: - Subscription Service Protocol
public protocol SubscriptionService: AnyObject {
    
    // MARK: - Publishers
    var subscriptionUpdatesPublisher: AnyPublisher<UserSubscription, Never> { get }
    var membershipUpdatesPublisher: AnyPublisher<StudioMembership?, Never> { get }
    
    // MARK: - Subscription Management
    func getCurrentSubscription(for userId: String) async throws -> UserSubscription?
    func createSubscription(_ subscription: UserSubscription) async throws -> UserSubscription
    func updateSubscription(_ subscription: UserSubscription) async throws -> UserSubscription
    func cancelSubscription(for userId: String) async throws
    func renewSubscription(for userId: String) async throws -> UserSubscription
    
    // MARK: - Studio Membership Management
    func getStudioMembership(for userId: String) async throws -> StudioMembership?
    func updateStudioMembership(_ membership: StudioMembership) async throws -> StudioMembership
    func refreshMembershipStatus(for userId: String) async throws -> StudioMembership?
    
    // MARK: - Access Level Management
    func getAccessLevel(for userId: String) async throws -> AccessLevel
    func hasAccess(userId: String, to content: AccessibleContent) async throws -> Bool
    func validateSubscriptionAccess(userId: String, programId: String) async throws -> Bool
    
    // MARK: - Billing and Payments
    func getBillingHistory(for userId: String) async throws -> [BillingRecord]
    func getNextBillingDate(for userId: String) async throws -> Date?
    func updatePaymentMethod(for userId: String, paymentMethod: PaymentMethod) async throws
}

// MARK: - Subscription Models
// Note: UserSubscription and StudioMembership are defined in ServiceModels.swift

public enum SubscriptionType: String, CaseIterable, Codable {
    case free = "free"
    case basic = "basic"
    case premium = "premium"
    case studio = "studio"
    case instructor = "instructor"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var accessLevel: AccessLevel {
        switch self {
        case .free: return .free
        case .basic: return .subscriber
        case .premium: return .subscriber
        case .studio: return .subscriber
        case .instructor: return .instructor
        }
    }
}

public enum SubscriptionStatus: String, CaseIterable, Codable {
    case active = "active"
    case inactive = "inactive"
    case cancelled = "cancelled"
    case expired = "expired"
    case suspended = "suspended"
    case trial = "trial"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var isValid: Bool {
        return self == .active || self == .trial
    }
}

public enum BillingCycle: String, CaseIterable, Codable {
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case lifetime = "lifetime"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var durationInMonths: Int {
        switch self {
        case .monthly: return 1
        case .quarterly: return 3
        case .yearly: return 12
        case .lifetime: return 0 // Special case
        }
    }
}

public struct SubscriptionPrice: Codable, Equatable {
    public let amount: Decimal
    public let currency: String
    public let originalAmount: Decimal?
    public let discountAmount: Decimal?
    
    public init(
        amount: Decimal,
        currency: String = "USD",
        originalAmount: Decimal? = nil,
        discountAmount: Decimal? = nil
    ) {
        self.amount = amount
        self.currency = currency
        self.originalAmount = originalAmount
        self.discountAmount = discountAmount
    }
    
    public var hasDiscount: Bool {
        return discountAmount != nil && discountAmount! > 0
    }
}

public enum SubscriptionFeature: String, CaseIterable, Codable {
    case unlimitedAccess = "unlimited_access"
    case premiumContent = "premium_content"
    case offlineDownloads = "offline_downloads"
    case personalizedRecommendations = "personalized_recommendations"
    case prioritySupport = "priority_support"
    case multiDeviceAccess = "multi_device_access"
    case studioDiscounts = "studio_discounts"
    case instructorTools = "instructor_tools"
    
    public var displayName: String {
        switch self {
        case .unlimitedAccess: return "Unlimited Access"
        case .premiumContent: return "Premium Content"
        case .offlineDownloads: return "Offline Downloads"
        case .personalizedRecommendations: return "Personalized Recommendations"
        case .prioritySupport: return "Priority Support"
        case .multiDeviceAccess: return "Multi-Device Access"
        case .studioDiscounts: return "Studio Discounts"
        case .instructorTools: return "Instructor Tools"
        }
    }
}

public enum MembershipBenefit: String, CaseIterable, Codable {
    case discountedSubscription = "discounted_subscription"
    case exclusiveContent = "exclusive_content"
    case priorityBooking = "priority_booking"
    case freeTrials = "free_trials"
    case specialEvents = "special_events"
    
    public var displayName: String {
        switch self {
        case .discountedSubscription: return "Discounted Subscription"
        case .exclusiveContent: return "Exclusive Content"
        case .priorityBooking: return "Priority Booking"
        case .freeTrials: return "Free Trials"
        case .specialEvents: return "Special Events"
        }
    }
}

public struct PaymentMethod: Codable, Equatable {
    public let id: String
    public let type: PaymentType
    public let last4: String?
    public let expiryMonth: Int?
    public let expiryYear: Int?
    public let brand: String?
    public let isDefault: Bool
    
    public init(
        id: String = UUID().uuidString,
        type: PaymentType,
        last4: String? = nil,
        expiryMonth: Int? = nil,
        expiryYear: Int? = nil,
        brand: String? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.type = type
        self.last4 = last4
        self.expiryMonth = expiryMonth
        self.expiryYear = expiryYear
        self.brand = brand
        self.isDefault = isDefault
    }
}

public enum PaymentType: String, CaseIterable, Codable {
    case creditCard = "credit_card"
    case debitCard = "debit_card"
    case paypal = "paypal"
    case applePay = "apple_pay"
    case googlePay = "google_pay"
    
    public var displayName: String {
        switch self {
        case .creditCard: return "Credit Card"
        case .debitCard: return "Debit Card"
        case .paypal: return "PayPal"
        case .applePay: return "Apple Pay"
        case .googlePay: return "Google Pay"
        }
    }
}

public struct BillingRecord: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let amount: Decimal
    public let currency: String
    public let date: Date
    public let status: BillingStatus
    public let description: String
    public let invoiceUrl: URL?
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        amount: Decimal,
        currency: String = "USD",
        date: Date,
        status: BillingStatus,
        description: String,
        invoiceUrl: URL? = nil
    ) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.currency = currency
        self.date = date
        self.status = status
        self.description = description
        self.invoiceUrl = invoiceUrl
    }
}

public enum BillingStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case paid = "paid"
    case failed = "failed"
    case refunded = "refunded"
    case cancelled = "cancelled"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Accessible Content Protocol
public protocol AccessibleContent {
    var id: String { get }
    var accessLevel: AccessLevel { get }
    var requiredSubscriptionType: SubscriptionType? { get }
    var isStudioExclusive: Bool { get }
}

// MARK: - Subscription Service Errors
public enum SubscriptionServiceError: Error, LocalizedError {
    case subscriptionNotFound(userId: String)
    case membershipNotFound(userId: String)
    case invalidSubscription(reason: String)
    case paymentFailed(reason: String)
    case unauthorized(userId: String)
    case subscriptionExpired(userId: String)
    case accessDenied(contentId: String, requiredLevel: AccessLevel)
    case billingError(underlying: Error)
    case networkError(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .subscriptionNotFound(let userId):
            return "No subscription found for user '\(userId)'"
        case .membershipNotFound(let userId):
            return "No studio membership found for user '\(userId)'"
        case .invalidSubscription(let reason):
            return "Invalid subscription: \(reason)"
        case .paymentFailed(let reason):
            return "Payment failed: \(reason)"
        case .unauthorized(let userId):
            return "User '\(userId)' is not authorized for this operation"
        case .subscriptionExpired(let userId):
            return "Subscription has expired for user '\(userId)'"
        case .accessDenied(let contentId, let requiredLevel):
            return "Access denied to content '\(contentId)'. Required access level: \(requiredLevel)"
        case .billingError(let error):
            return "Billing error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}