import Foundation
import Combine
import UIKit

// MARK: - Media Service Protocol
public protocol MediaService {
    
    // MARK: - Media Upload
    func uploadImage(_ image: UIImage, metadata: MediaMetadata) async throws -> MediaItem
    func uploadVideo(from url: URL, metadata: MediaMetadata) async throws -> MediaItem
    func uploadAudio(from url: URL, metadata: MediaMetadata) async throws -> MediaItem
    func uploadDocument(from url: URL, metadata: MediaMetadata) async throws -> MediaItem
    
    // MARK: - Media Download
    func downloadMedia(id: String) async throws -> Data
    func downloadMediaToFile(id: String, destinationURL: URL) async throws -> URL
    func getMediaURL(id: String) async throws -> URL
    func getCachedMediaURL(id: String) -> URL?
    
    // MARK: - Media Management
    func getMediaItem(id: String) async throws -> MediaItem?
    func updateMediaMetadata(id: String, metadata: MediaMetadata) async throws -> MediaItem
    func deleteMedia(id: String) async throws
    func getMediaItems(for resourceId: String, resourceType: MediaResourceType) async throws -> [MediaItem]
    
    // MARK: - Media Processing
    func generateThumbnail(for mediaId: String) async throws -> UIImage
    func processVideo(mediaId: String, settings: VideoProcessingSettings) async throws -> MediaItem
    func extractAudioFromVideo(mediaId: String) async throws -> MediaItem
    func compressImage(mediaId: String, quality: ImageCompressionQuality) async throws -> MediaItem
    
    // MARK: - Media Validation
    func validateMedia(at url: URL, type: MediaType) async throws -> MediaValidationResult
    func scanMediaForContent(mediaId: String) async throws -> ContentScanResult
    
    // MARK: - Streaming and Playback
    func getStreamingURL(for mediaId: String, quality: StreamingQuality) async throws -> URL
    func prefetchMedia(ids: [String]) async throws
    func clearMediaCache() async throws
    func getCacheSize() async throws -> Int64
    
    // MARK: - Access Control
    func checkMediaAccess(mediaId: String, userId: String) async throws -> Bool
    func setMediaAccess(mediaId: String, accessLevel: MediaAccessLevel) async throws -> MediaItem
    func getMediaAccessLog(mediaId: String) async throws -> [MediaAccessEvent]
    
    // MARK: - Search and Discovery
    func searchMedia(query: String, filters: MediaSearchFilters) async throws -> [MediaItem]
    func getRecentMedia(limit: Int) async throws -> [MediaItem]
    func getPopularMedia(limit: Int) async throws -> [MediaItem]
    func getMediaByTag(tag: String) async throws -> [MediaItem]
    
    // MARK: - Publisher for Real-time Updates
    var mediaUpdatesPublisher: AnyPublisher<MediaItem, Never> { get }
    var uploadProgressPublisher: AnyPublisher<MediaUploadProgress, Never> { get }
    var downloadProgressPublisher: AnyPublisher<MediaDownloadProgress, Never> { get }
}

// MARK: - Media Item
public struct MediaItem: Identifiable, Codable, Equatable {
    public let id: String
    public let filename: String
    public let originalFilename: String
    public let type: MediaType
    public let mimeType: String
    public let size: Int64
    public let duration: TimeInterval? // For video/audio
    public let dimensions: MediaDimensions? // For images/video
    public let url: String
    public let thumbnailUrl: String?
    public let metadata: MediaMetadata
    public let accessLevel: MediaAccessLevel
    public let resourceId: String // Associated curriculum item, user profile, etc.
    public let resourceType: MediaResourceType
    public let uploadedBy: String // User ID
    public let uploadedAt: Date
    public var updatedAt: Date
    public let processingStatus: ProcessingStatus
    public let tags: [String]
    public let checksum: String
    
    public init(id: String = UUID().uuidString,
                filename: String,
                originalFilename: String,
                type: MediaType,
                mimeType: String,
                size: Int64,
                duration: TimeInterval? = nil,
                dimensions: MediaDimensions? = nil,
                url: String,
                thumbnailUrl: String? = nil,
                metadata: MediaMetadata,
                accessLevel: MediaAccessLevel,
                resourceId: String,
                resourceType: MediaResourceType,
                uploadedBy: String,
                processingStatus: ProcessingStatus = .pending,
                tags: [String] = [],
                checksum: String) {
        self.id = id
        self.filename = filename
        self.originalFilename = originalFilename
        self.type = type
        self.mimeType = mimeType
        self.size = size
        self.duration = duration
        self.dimensions = dimensions
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.metadata = metadata
        self.accessLevel = accessLevel
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.uploadedBy = uploadedBy
        self.uploadedAt = Date()
        self.updatedAt = Date()
        self.processingStatus = processingStatus
        self.tags = tags
        self.checksum = checksum
    }
}

// MARK: - Media Types
public enum MediaType: String, Codable, CaseIterable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var allowedMimeTypes: [String] {
        switch self {
        case .image:
            return ["image/jpeg", "image/png", "image/gif", "image/webp", "image/heic"]
        case .video:
            return ["video/mp4", "video/mov", "video/avi", "video/mkv", "video/webm"]
        case .audio:
            return ["audio/mp3", "audio/wav", "audio/aac", "audio/ogg", "audio/m4a"]
        case .document:
            return ["application/pdf", "text/plain", "application/msword", 
                   "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
        }
    }
    
    public var maxFileSize: Int64 {
        switch self {
        case .image: return 50 * 1024 * 1024 // 50MB
        case .video: return 500 * 1024 * 1024 // 500MB
        case .audio: return 100 * 1024 * 1024 // 100MB
        case .document: return 25 * 1024 * 1024 // 25MB
        }
    }
}

// MARK: - Media Resource Type
public enum MediaResourceType: String, Codable, CaseIterable {
    case curriculumItem = "curriculum_item"
    case userProfile = "user_profile"
    case program = "program"
    case announcement = "announcement"
    case practiceSession = "practice_session"
    case achievement = "achievement"
    case general = "general"
    
    public var displayName: String {
        switch self {
        case .curriculumItem: return "Curriculum Item"
        case .userProfile: return "User Profile"
        case .program: return "Program"
        case .announcement: return "Announcement"
        case .practiceSession: return "Practice Session"
        case .achievement: return "Achievement"
        case .general: return "General"
        }
    }
}

// MARK: - Media Access Level
public enum MediaAccessLevel: String, Codable, CaseIterable {
    case publicAccess = "public"
    case subscribersOnly = "subscribers"
    case instructorsOnly = "instructors"
    case privateAccess = "private"
    
    public var displayName: String {
        switch self {
        case .publicAccess: return "Public"
        case .subscribersOnly: return "Subscribers Only"
        case .instructorsOnly: return "Instructors Only"
        case .privateAccess: return "Private"
        }
    }
    
    public var requiredAccessLevel: AccessLevel {
        switch self {
        case .publicAccess: return .free
        case .subscribersOnly: return .subscriber
        case .instructorsOnly: return .instructor
        case .privateAccess: return .instructor
        }
    }
}

// MARK: - Processing Status
public enum ProcessingStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var isProcessing: Bool {
        return self == .pending || self == .processing
    }
}

// MARK: - Media Metadata
public struct MediaMetadata: Codable, Equatable {
    public var title: String?
    public var description: String?
    public var alt: String?
    public var caption: String?
    public var author: String?
    public var copyright: String?
    public var keywords: [String]
    public var location: MediaLocation?
    public var cameraMake: String?
    public var cameraModel: String?
    public var lens: String?
    public var focalLength: String?
    public var aperture: String?
    public var shutterSpeed: String?
    public var iso: String?
    public var customFields: [String: String]
    
    public init(title: String? = nil,
                description: String? = nil,
                alt: String? = nil,
                caption: String? = nil,
                author: String? = nil,
                copyright: String? = nil,
                keywords: [String] = [],
                location: MediaLocation? = nil,
                cameraMake: String? = nil,
                cameraModel: String? = nil,
                lens: String? = nil,
                focalLength: String? = nil,
                aperture: String? = nil,
                shutterSpeed: String? = nil,
                iso: String? = nil,
                customFields: [String: String] = [:]) {
        self.title = title
        self.description = description
        self.alt = alt
        self.caption = caption
        self.author = author
        self.copyright = copyright
        self.keywords = keywords
        self.location = location
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.lens = lens
        self.focalLength = focalLength
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.iso = iso
        self.customFields = customFields
    }
}

// MARK: - Media Location
public struct MediaLocation: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let name: String?
    public let address: String?
    
    public init(latitude: Double,
                longitude: Double,
                altitude: Double? = nil,
                name: String? = nil,
                address: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.name = name
        self.address = address
    }
}

// MARK: - Media Dimensions
public struct MediaDimensions: Codable, Equatable {
    public let width: Int
    public let height: Int
    public let aspectRatio: Double
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.aspectRatio = Double(width) / Double(height)
    }
}

// MARK: - Video Processing Settings
public struct VideoProcessingSettings: Codable {
    public let quality: VideoQuality
    public let resolution: VideoResolution?
    public let bitrate: Int?
    public let framerate: Int?
    public let codec: VideoCodec
    public let trim: VideoTrimSettings?
    
    public init(quality: VideoQuality = .high,
                resolution: VideoResolution? = nil,
                bitrate: Int? = nil,
                framerate: Int? = nil,
                codec: VideoCodec = .h264,
                trim: VideoTrimSettings? = nil) {
        self.quality = quality
        self.resolution = resolution
        self.bitrate = bitrate
        self.framerate = framerate
        self.codec = codec
        self.trim = trim
    }
    
    public enum VideoQuality: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case ultra = "ultra"
    }
    
    public enum VideoResolution: String, Codable, CaseIterable {
        case sd480 = "480p"
        case hd720 = "720p"
        case hd1080 = "1080p"
        case uhd4k = "4k"
    }
    
    public enum VideoCodec: String, Codable, CaseIterable {
        case h264 = "h264"
        case h265 = "h265"
        case vp9 = "vp9"
        case av1 = "av1"
    }
}

// MARK: - Video Trim Settings
public struct VideoTrimSettings: Codable {
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    
    public init(startTime: TimeInterval, endTime: TimeInterval) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - Image Compression Quality
public enum ImageCompressionQuality: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case lossless = "lossless"
    
    public var compressionValue: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.8
        case .lossless: return 1.0
        }
    }
}

// MARK: - Streaming Quality
public enum StreamingQuality: String, Codable, CaseIterable {
    case auto = "auto"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case original = "original"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Media Validation Result
public struct MediaValidationResult: Codable {
    public let isValid: Bool
    public let fileSize: Int64
    public let mimeType: String
    public let duration: TimeInterval?
    public let dimensions: MediaDimensions?
    public let errors: [String]
    public let warnings: [String]
    
    public init(isValid: Bool,
                fileSize: Int64,
                mimeType: String,
                duration: TimeInterval? = nil,
                dimensions: MediaDimensions? = nil,
                errors: [String] = [],
                warnings: [String] = []) {
        self.isValid = isValid
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.duration = duration
        self.dimensions = dimensions
        self.errors = errors
        self.warnings = warnings
    }
}

// MARK: - Content Scan Result
public struct ContentScanResult: Codable {
    public let isAppropriate: Bool
    public let confidence: Double
    public let flags: [ContentFlag]
    public let text: String?
    public let objects: [DetectedObject]
    
    public init(isAppropriate: Bool,
                confidence: Double,
                flags: [ContentFlag] = [],
                text: String? = nil,
                objects: [DetectedObject] = []) {
        self.isAppropriate = isAppropriate
        self.confidence = confidence
        self.flags = flags
        self.text = text
        self.objects = objects
    }
    
    public enum ContentFlag: String, Codable, CaseIterable {
        case inappropriate = "inappropriate"
        case violent = "violent"
        case adult = "adult"
        case spam = "spam"
        case copyright = "copyright"
        case lowQuality = "low_quality"
    }
}

// MARK: - Detected Object
public struct DetectedObject: Codable {
    public let name: String
    public let confidence: Double
    public let boundingBox: BoundingBox?
    
    public init(name: String, confidence: Double, boundingBox: BoundingBox? = nil) {
        self.name = name
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

// MARK: - Bounding Box
public struct BoundingBox: Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - Media Search Filters
public struct MediaSearchFilters: Codable {
    public let types: [MediaType]
    public let resourceTypes: [MediaResourceType]
    public let accessLevels: [MediaAccessLevel]
    public let uploadedAfter: Date?
    public let uploadedBefore: Date?
    public let minSize: Int64?
    public let maxSize: Int64?
    public let tags: [String]
    public let uploadedBy: String?
    
    public init(types: [MediaType] = MediaType.allCases,
                resourceTypes: [MediaResourceType] = MediaResourceType.allCases,
                accessLevels: [MediaAccessLevel] = MediaAccessLevel.allCases,
                uploadedAfter: Date? = nil,
                uploadedBefore: Date? = nil,
                minSize: Int64? = nil,
                maxSize: Int64? = nil,
                tags: [String] = [],
                uploadedBy: String? = nil) {
        self.types = types
        self.resourceTypes = resourceTypes
        self.accessLevels = accessLevels
        self.uploadedAfter = uploadedAfter
        self.uploadedBefore = uploadedBefore
        self.minSize = minSize
        self.maxSize = maxSize
        self.tags = tags
        self.uploadedBy = uploadedBy
    }
}

// MARK: - Media Access Event
public struct MediaAccessEvent: Identifiable, Codable {
    public let id = UUID()
    public let mediaId: String
    public let userId: String
    public let accessType: AccessType
    public let timestamp: Date
    public let userAgent: String?
    public let ipAddress: String?
    
    public init(mediaId: String,
                userId: String,
                accessType: AccessType,
                userAgent: String? = nil,
                ipAddress: String? = nil) {
        self.mediaId = mediaId
        self.userId = userId
        self.accessType = accessType
        self.timestamp = Date()
        self.userAgent = userAgent
        self.ipAddress = ipAddress
    }
    
    public enum AccessType: String, Codable, CaseIterable {
        case view = "view"
        case download = "download"
        case stream = "stream"
        case share = "share"
    }
}

// MARK: - Upload/Download Progress
public struct MediaUploadProgress: Identifiable {
    public let id = UUID()
    public let mediaId: String
    public let bytesUploaded: Int64
    public let totalBytes: Int64
    public let progress: Double
    public let isCompleted: Bool
    public let error: Error?
    
    public init(mediaId: String,
                bytesUploaded: Int64,
                totalBytes: Int64,
                error: Error? = nil) {
        self.mediaId = mediaId
        self.bytesUploaded = bytesUploaded
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? Double(bytesUploaded) / Double(totalBytes) : 0.0
        self.isCompleted = bytesUploaded >= totalBytes && error == nil
        self.error = error
    }
}

public struct MediaDownloadProgress: Identifiable {
    public let id = UUID()
    public let mediaId: String
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let progress: Double
    public let isCompleted: Bool
    public let error: Error?
    
    public init(mediaId: String,
                bytesDownloaded: Int64,
                totalBytes: Int64,
                error: Error? = nil) {
        self.mediaId = mediaId
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? Double(bytesDownloaded) / Double(totalBytes) : 0.0
        self.isCompleted = bytesDownloaded >= totalBytes && error == nil
        self.error = error
    }
}

// MARK: - Media Service Errors
public enum MediaServiceError: LocalizedError, Equatable {
    case mediaNotFound(id: String)
    case invalidMediaType(type: String)
    case fileSizeTooLarge(size: Int64, maxSize: Int64)
    case unsupportedMimeType(mimeType: String)
    case uploadFailed(reason: String)
    case downloadFailed(reason: String)
    case processingFailed(reason: String)
    case invalidMetadata(field: String)
    case accessDenied(mediaId: String, userId: String)
    case insufficientStorage
    case mediaCorrupted(mediaId: String)
    case thumbnailGenerationFailed(mediaId: String)
    case streamingNotAvailable(mediaId: String)
    case cacheError(reason: String)
    case validationFailed(errors: [String])
    case contentScanFailed(reason: String)
    case networkError(underlying: Error)
    case unknown(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .mediaNotFound(let id):
            return "Media not found: \(id)"
        case .invalidMediaType(let type):
            return "Invalid media type: \(type)"
        case .fileSizeTooLarge(let size, let maxSize):
            return "File size \(size) exceeds maximum allowed size \(maxSize)"
        case .unsupportedMimeType(let mimeType):
            return "Unsupported MIME type: \(mimeType)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .invalidMetadata(let field):
            return "Invalid metadata for field: \(field)"
        case .accessDenied(let mediaId, let userId):
            return "Access denied for user \(userId) to media \(mediaId)"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .mediaCorrupted(let mediaId):
            return "Media corrupted: \(mediaId)"
        case .thumbnailGenerationFailed(let mediaId):
            return "Thumbnail generation failed for media: \(mediaId)"
        case .streamingNotAvailable(let mediaId):
            return "Streaming not available for media: \(mediaId)"
        case .cacheError(let reason):
            return "Cache error: \(reason)"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .contentScanFailed(let reason):
            return "Content scan failed: \(reason)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .unknown(let underlying):
            return "Unknown error: \(underlying.localizedDescription)"
        }
    }
    
    public static func == (lhs: MediaServiceError, rhs: MediaServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.mediaNotFound(let lhsId), .mediaNotFound(let rhsId)):
            return lhsId == rhsId
        case (.invalidMediaType(let lhsType), .invalidMediaType(let rhsType)):
            return lhsType == rhsType
        case (.fileSizeTooLarge(let lhsSize, let lhsMaxSize), .fileSizeTooLarge(let rhsSize, let rhsMaxSize)):
            return lhsSize == rhsSize && lhsMaxSize == rhsMaxSize
        case (.unsupportedMimeType(let lhsMimeType), .unsupportedMimeType(let rhsMimeType)):
            return lhsMimeType == rhsMimeType
        case (.uploadFailed(let lhsReason), .uploadFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.downloadFailed(let lhsReason), .downloadFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.processingFailed(let lhsReason), .processingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.invalidMetadata(let lhsField), .invalidMetadata(let rhsField)):
            return lhsField == rhsField
        case (.accessDenied(let lhsMediaId, let lhsUserId), .accessDenied(let rhsMediaId, let rhsUserId)):
            return lhsMediaId == rhsMediaId && lhsUserId == rhsUserId
        case (.insufficientStorage, .insufficientStorage):
            return true
        case (.mediaCorrupted(let lhsMediaId), .mediaCorrupted(let rhsMediaId)):
            return lhsMediaId == rhsMediaId
        case (.thumbnailGenerationFailed(let lhsMediaId), .thumbnailGenerationFailed(let rhsMediaId)):
            return lhsMediaId == rhsMediaId
        case (.streamingNotAvailable(let lhsMediaId), .streamingNotAvailable(let rhsMediaId)):
            return lhsMediaId == rhsMediaId
        case (.cacheError(let lhsReason), .cacheError(let rhsReason)):
            return lhsReason == rhsReason
        case (.validationFailed(let lhsErrors), .validationFailed(let rhsErrors)):
            return lhsErrors == rhsErrors
        case (.contentScanFailed(let lhsReason), .contentScanFailed(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
}

// MARK: - Access Event Type
public enum AccessEventType: String, Codable, CaseIterable {
    case view = "view"
    case download = "download"
    case share = "share"
    case bookmark = "bookmark"
    case print = "print"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}