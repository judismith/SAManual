import Foundation
import CloudKit

// MARK: - User Data Transfer Object
public struct UserDTO: Codable {
    public let id: String
    public let email: String
    public let name: String
    public let userType: String
    public let membershipType: String?
    public let accessLevel: String
    public let dataStore: String
    public let createdAt: Date
    public let updatedAt: Date
    public let isActive: Bool
    public let profile: UserProfileDTO?
    public let enrollments: [ProgramEnrollmentDTO]
    
    public init(
        id: String,
        email: String,
        name: String,
        userType: String,
        membershipType: String? = nil,
        accessLevel: String,
        dataStore: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true,
        profile: UserProfileDTO? = nil,
        enrollments: [ProgramEnrollmentDTO] = []
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.userType = userType
        self.membershipType = membershipType
        self.accessLevel = accessLevel
        self.dataStore = dataStore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.profile = profile
        self.enrollments = enrollments
    }
}

// MARK: - User Profile DTO
public struct UserProfileDTO: Codable {
    public let firstName: String?
    public let lastName: String?
    public let dateOfBirth: Date?
    public let phoneNumber: String?
    public let emergencyContact: EmergencyContactDTO?
    public let preferences: UserPreferencesDTO?
    
    public init(
        firstName: String? = nil,
        lastName: String? = nil,
        dateOfBirth: Date? = nil,
        phoneNumber: String? = nil,
        emergencyContact: EmergencyContactDTO? = nil,
        preferences: UserPreferencesDTO? = nil
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.phoneNumber = phoneNumber
        self.emergencyContact = emergencyContact
        self.preferences = preferences
    }
}

// MARK: - Emergency Contact DTO
public struct EmergencyContactDTO: Codable {
    public let name: String
    public let relationship: String
    public let phoneNumber: String
    public let email: String?
    
    public init(name: String, relationship: String, phoneNumber: String, email: String? = nil) {
        self.name = name
        self.relationship = relationship
        self.phoneNumber = phoneNumber
        self.email = email
    }
}

// MARK: - User Preferences DTO
public struct UserPreferencesDTO: Codable {
    public let notificationsEnabled: Bool
    public let emailNotifications: Bool
    public let pushNotifications: Bool
    public let practiceReminders: Bool
    public let language: String
    public let timeZone: String
    
    public init(
        notificationsEnabled: Bool = true,
        emailNotifications: Bool = true,
        pushNotifications: Bool = true,
        practiceReminders: Bool = true,
        language: String = "en",
        timeZone: String = "UTC"
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.emailNotifications = emailNotifications
        self.pushNotifications = pushNotifications
        self.practiceReminders = practiceReminders
        self.language = language
        self.timeZone = timeZone
    }
}

// MARK: - Program Enrollment DTO
public struct ProgramEnrollmentDTO: Codable {
    public let id: String
    public let userId: String
    public let programId: String
    public let enrolled: Bool
    public let enrollmentDate: Date?
    public let startDate: Date?
    public let endDate: Date?
    public let currentRank: String?
    public let progress: Double
    
    public init(
        id: String,
        userId: String,
        programId: String,
        enrolled: Bool = false,
        enrollmentDate: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        currentRank: String? = nil,
        progress: Double = 0.0
    ) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.enrolled = enrolled
        self.enrollmentDate = enrollmentDate
        self.startDate = startDate
        self.endDate = endDate
        self.currentRank = currentRank
        self.progress = progress
    }
    
    // MARK: - CloudKit Conversion
    public static func from(_ data: [String: Any]) throws -> ProgramEnrollmentDTO {
        guard let id = data["id"] as? String,
              let userId = data["userId"] as? String,
              let programId = data["programId"] as? String else {
            throw AppError.dataValidationFailed(entity: "ProgramEnrollment", field: "required_fields", message: "Missing required fields")
        }
        
        let enrolled = data["enrolled"] as? Bool ?? false
        let enrollmentDate = data["enrollmentDate"] as? Date
        let startDate = data["startDate"] as? Date
        let endDate = data["endDate"] as? Date
        let currentRank = data["currentRank"] as? String
        let progress = data["progress"] as? Double ?? 0.0
        
        return ProgramEnrollmentDTO(
            id: id,
            userId: userId,
            programId: programId,
            enrolled: enrolled,
            enrollmentDate: enrollmentDate,
            startDate: startDate,
            endDate: endDate,
            currentRank: currentRank,
            progress: progress
        )
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "userId": userId,
            "programId": programId,
            "enrolled": enrolled,
            "progress": progress
        ]
        
        if let enrollmentDate = enrollmentDate {
            dict["enrollmentDate"] = enrollmentDate
        }
        if let startDate = startDate {
            dict["startDate"] = startDate
        }
        if let endDate = endDate {
            dict["endDate"] = endDate
        }
        if let currentRank = currentRank {
            dict["currentRank"] = currentRank
        }
        
        return dict
    }
}

// MARK: - UserDTO CloudKit Extensions
extension UserDTO {
    public static func from(_ record: CKRecord) throws -> UserDTO {
        guard let email = record["email"] as? String,
              let name = record["name"] as? String,
              let userType = record["userType"] as? String,
              let accessLevel = record["accessLevel"] as? String,
              let dataStore = record["dataStore"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let isActive = record["isActive"] as? Bool else {
            throw AppError.dataValidationFailed(entity: "User", field: "required_fields", message: "Missing required fields in CloudKit record")
        }
        
        let membershipType = record["membershipType"] as? String
        
        // Decode profile from Data
        var profile: UserProfileDTO? = nil
        if let profileData = record["profile"] as? Data {
            profile = try? JSONDecoder().decode(UserProfileDTO.self, from: profileData)
        }
        // Decode enrollments from Data
        var enrollments: [ProgramEnrollmentDTO] = []
        if let enrollmentsData = record["enrollments"] as? Data {
            enrollments = (try? JSONDecoder().decode([ProgramEnrollmentDTO].self, from: enrollmentsData)) ?? []
        }
        
        return UserDTO(
            id: record.recordID.recordName,
            email: email,
            name: name,
            userType: userType,
            membershipType: membershipType,
            accessLevel: accessLevel,
            dataStore: dataStore,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isActive: isActive,
            profile: profile,
            enrollments: enrollments
        )
    }
    
    public func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "User")
        record["email"] = email as CKRecordValue
        record["name"] = name as CKRecordValue
        record["userType"] = userType as CKRecordValue
        record["membershipType"] = membershipType as CKRecordValue?
        record["accessLevel"] = accessLevel as CKRecordValue
        record["dataStore"] = dataStore as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        record["isActive"] = isActive as CKRecordValue
        
        // Encode profile to Data
        if let profile = profile {
            if let profileData = try? JSONEncoder().encode(profile) {
                record["profile"] = profileData as CKRecordValue
            }
        }
        // Encode enrollments to Data
        if !enrollments.isEmpty {
            if let enrollmentsData = try? JSONEncoder().encode(enrollments) {
                record["enrollments"] = enrollmentsData as CKRecordValue
            }
        }
        
        return record
    }
}

// MARK: - UserProfileDTO CloudKit Extensions
extension UserProfileDTO {
    public static func from(_ data: [String: Any]) throws -> UserProfileDTO {
        let firstName = data["firstName"] as? String
        let lastName = data["lastName"] as? String
        let dateOfBirth = data["dateOfBirth"] as? Date
        let phoneNumber = data["phoneNumber"] as? String
        let emergencyContactData = data["emergencyContact"] as? [String: Any]
        let preferencesData = data["preferences"] as? [String: Any]
        
        let emergencyContact: EmergencyContactDTO?
        if let emergencyContactData = emergencyContactData {
            emergencyContact = try EmergencyContactDTO.from(emergencyContactData)
        } else {
            emergencyContact = nil
        }
        
        let preferences: UserPreferencesDTO?
        if let preferencesData = preferencesData {
            preferences = try UserPreferencesDTO.from(preferencesData)
        } else {
            preferences = nil
        }
        
        return UserProfileDTO(
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            phoneNumber: phoneNumber,
            emergencyContact: emergencyContact,
            preferences: preferences
        )
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let firstName = firstName {
            dict["firstName"] = firstName
        }
        if let lastName = lastName {
            dict["lastName"] = lastName
        }
        if let dateOfBirth = dateOfBirth {
            dict["dateOfBirth"] = dateOfBirth
        }
        if let phoneNumber = phoneNumber {
            dict["phoneNumber"] = phoneNumber
        }
        if let emergencyContact = emergencyContact {
            dict["emergencyContact"] = emergencyContact.toDictionary()
        }
        if let preferences = preferences {
            dict["preferences"] = preferences.toDictionary()
        }
        
        return dict
    }
}

// MARK: - EmergencyContactDTO CloudKit Extensions
extension EmergencyContactDTO {
    public static func from(_ data: [String: Any]) throws -> EmergencyContactDTO {
        guard let name = data["name"] as? String,
              let relationship = data["relationship"] as? String,
              let phoneNumber = data["phoneNumber"] as? String else {
            throw AppError.dataValidationFailed(entity: "EmergencyContact", field: "required_fields", message: "Missing required fields")
        }
        
        let email = data["email"] as? String
        
        return EmergencyContactDTO(
            name: name,
            relationship: relationship,
            phoneNumber: phoneNumber,
            email: email
        )
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "relationship": relationship,
            "phoneNumber": phoneNumber
        ]
        
        if let email = email {
            dict["email"] = email
        }
        
        return dict
    }
}

// MARK: - UserPreferencesDTO CloudKit Extensions
extension UserPreferencesDTO {
    public static func from(_ data: [String: Any]) throws -> UserPreferencesDTO {
        let notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true
        let emailNotifications = data["emailNotifications"] as? Bool ?? true
        let pushNotifications = data["pushNotifications"] as? Bool ?? true
        let practiceReminders = data["practiceReminders"] as? Bool ?? true
        let language = data["language"] as? String ?? "en"
        let timeZone = data["timeZone"] as? String ?? "UTC"
        
        return UserPreferencesDTO(
            notificationsEnabled: notificationsEnabled,
            emailNotifications: emailNotifications,
            pushNotifications: pushNotifications,
            practiceReminders: practiceReminders,
            language: language,
            timeZone: timeZone
        )
    }
    
    public func toDictionary() -> [String: Any] {
        return [
            "notificationsEnabled": notificationsEnabled,
            "emailNotifications": emailNotifications,
            "pushNotifications": pushNotifications,
            "practiceReminders": practiceReminders,
            "language": language,
            "timeZone": timeZone
        ]
    }
} 