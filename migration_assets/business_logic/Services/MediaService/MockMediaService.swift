import Foundation
import Combine
import UIKit

// MARK: - Mock Media Service Implementation
public final class MockMediaService: MediaService {
    
    // MARK: - In-Memory Storage
    private var mediaItems: [String: MediaItem] = [:]
    private var mediaData: [String: Data] = [:]
    private var accessLogs: [String: [MediaAccessEvent]] = [:]
    private var cacheSize: Int64 = 0
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    
    // MARK: - Publishers
    private let mediaUpdatesSubject = PassthroughSubject<MediaItem, Never>()
    private let uploadProgressSubject = PassthroughSubject<MediaUploadProgress, Never>()
    private let downloadProgressSubject = PassthroughSubject<MediaDownloadProgress, Never>()
    
    public var mediaUpdatesPublisher: AnyPublisher<MediaItem, Never> {
        mediaUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var uploadProgressPublisher: AnyPublisher<MediaUploadProgress, Never> {
        uploadProgressSubject.eraseToAnyPublisher()
    }
    
    public var downloadProgressPublisher: AnyPublisher<MediaDownloadProgress, Never> {
        downloadProgressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    public init() {
        seedSampleData()
    }
    
    // MARK: - Media Upload
    public func uploadImage(_ image: UIImage, metadata: MediaMetadata) async throws -> MediaItem {
        // Simulate network delay and progress
        let mediaId = UUID().uuidString
        let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        
        // Simulate upload progress
        await simulateUploadProgress(mediaId: mediaId, totalBytes: Int64(imageData.count))
        
        let mediaItem = MediaItem(
            id: mediaId,
            filename: "image_\(mediaId).jpg",
            originalFilename: "uploaded_image.jpg",
            type: .image,
            mimeType: "image/jpeg",
            size: Int64(imageData.count),
            dimensions: MediaDimensions(width: Int(image.size.width), height: Int(image.size.height)),
            url: "mock://media/\(mediaId)",
            thumbnailUrl: "mock://thumbnails/\(mediaId)",
            metadata: metadata,
            accessLevel: .publicAccess,
            resourceId: metadata.customFields["resourceId"] ?? "",
            resourceType: MediaResourceType(rawValue: metadata.customFields["resourceType"] ?? "general") ?? .general,
            uploadedBy: metadata.customFields["uploadedBy"] ?? "mock-user",
            processingStatus: .completed,
            checksum: "mock-checksum-\(mediaId)"
        )
        
        mediaItems[mediaId] = mediaItem
        mediaData[mediaId] = imageData
        cacheSize += Int64(imageData.count)
        
        mediaUpdatesSubject.send(mediaItem)
        return mediaItem
    }
    
    public func uploadVideo(from url: URL, metadata: MediaMetadata) async throws -> MediaItem {
        // Simulate reading video file
        let videoData = try Data(contentsOf: url)
        let mediaId = UUID().uuidString
        
        // Simulate upload progress
        await simulateUploadProgress(mediaId: mediaId, totalBytes: Int64(videoData.count))
        
        let mediaItem = MediaItem(
            id: mediaId,
            filename: "video_\(mediaId).mp4",
            originalFilename: url.lastPathComponent,
            type: .video,
            mimeType: "video/mp4",
            size: Int64(videoData.count),
            duration: 120.0, // Mock 2-minute video
            dimensions: MediaDimensions(width: 1920, height: 1080),
            url: "mock://media/\(mediaId)",
            thumbnailUrl: "mock://thumbnails/\(mediaId)",
            metadata: metadata,
            accessLevel: .subscribersOnly,
            resourceId: metadata.customFields["resourceId"] ?? "",
            resourceType: MediaResourceType(rawValue: metadata.customFields["resourceType"] ?? "general") ?? .general,
            uploadedBy: metadata.customFields["uploadedBy"] ?? "mock-user",
            processingStatus: .processing,
            checksum: "mock-checksum-\(mediaId)"
        )
        
        mediaItems[mediaId] = mediaItem
        mediaData[mediaId] = videoData
        cacheSize += Int64(videoData.count)
        
        // Simulate processing completion after delay
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            var processedItem = mediaItem
            processedItem.processingStatus = .completed
            mediaItems[mediaId] = processedItem
            mediaUpdatesSubject.send(processedItem)
        }
        
        mediaUpdatesSubject.send(mediaItem)
        return mediaItem
    }
    
    public func uploadAudio(from url: URL, metadata: MediaMetadata) async throws -> MediaItem {
        let audioData = try Data(contentsOf: url)
        let mediaId = UUID().uuidString
        
        await simulateUploadProgress(mediaId: mediaId, totalBytes: Int64(audioData.count))
        
        let mediaItem = MediaItem(
            id: mediaId,
            filename: "audio_\(mediaId).mp3",
            originalFilename: url.lastPathComponent,
            type: .audio,
            mimeType: "audio/mp3",
            size: Int64(audioData.count),
            duration: 180.0, // Mock 3-minute audio
            url: "mock://media/\(mediaId)",
            metadata: metadata,
            accessLevel: .publicAccess,
            resourceId: metadata.customFields["resourceId"] ?? "",
            resourceType: MediaResourceType(rawValue: metadata.customFields["resourceType"] ?? "general") ?? .general,
            uploadedBy: metadata.customFields["uploadedBy"] ?? "mock-user",
            processingStatus: .completed,
            checksum: "mock-checksum-\(mediaId)"
        )
        
        mediaItems[mediaId] = mediaItem
        mediaData[mediaId] = audioData
        cacheSize += Int64(audioData.count)
        
        mediaUpdatesSubject.send(mediaItem)
        return mediaItem
    }
    
    public func uploadDocument(from url: URL, metadata: MediaMetadata) async throws -> MediaItem {
        let documentData = try Data(contentsOf: url)
        let mediaId = UUID().uuidString
        
        await simulateUploadProgress(mediaId: mediaId, totalBytes: Int64(documentData.count))
        
        let mediaItem = MediaItem(
            id: mediaId,
            filename: "document_\(mediaId).pdf",
            originalFilename: url.lastPathComponent,
            type: .document,
            mimeType: "application/pdf",
            size: Int64(documentData.count),
            url: "mock://media/\(mediaId)",
            metadata: metadata,
            accessLevel: .instructorsOnly,
            resourceId: metadata.customFields["resourceId"] ?? "",
            resourceType: MediaResourceType(rawValue: metadata.customFields["resourceType"] ?? "general") ?? .general,
            uploadedBy: metadata.customFields["uploadedBy"] ?? "mock-user",
            processingStatus: .completed,
            checksum: "mock-checksum-\(mediaId)"
        )
        
        mediaItems[mediaId] = mediaItem
        mediaData[mediaId] = documentData
        cacheSize += Int64(documentData.count)
        
        mediaUpdatesSubject.send(mediaItem)
        return mediaItem
    }
    
    // MARK: - Media Download
    public func downloadMedia(id: String) async throws -> Data {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let mediaItem = mediaItems[id] else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        guard let data = mediaData[id] else {
            throw MediaServiceError.downloadFailed(reason: "Media data not found")
        }
        
        // Simulate download progress
        await simulateDownloadProgress(mediaId: id, totalBytes: mediaItem.size)
        
        // Log access
        await logMediaAccess(mediaId: id, userId: "mock-user", accessType: .download)
        
        return data
    }
    
    public func downloadMediaToFile(id: String, destinationURL: URL) async throws -> URL {
        let data = try await downloadMedia(id: id)
        try data.write(to: destinationURL)
        return destinationURL
    }
    
    public func getMediaURL(id: String) async throws -> URL {
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        guard let mediaItem = mediaItems[id] else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        await logMediaAccess(mediaId: id, userId: "mock-user", accessType: .view)
        
        return URL(string: mediaItem.url)!
    }
    
    public func getCachedMediaURL(id: String) -> URL? {
        guard mediaItems[id] != nil else { return nil }
        return URL(string: "mock://cache/\(id)")
    }
    
    // MARK: - Media Management
    public func getMediaItem(id: String) async throws -> MediaItem? {
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return mediaItems[id]
    }
    
    public func updateMediaMetadata(id: String, metadata: MediaMetadata) async throws -> MediaItem {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard var mediaItem = mediaItems[id] else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        mediaItem.metadata = metadata
        mediaItem.updatedAt = Date()
        
        mediaItems[id] = mediaItem
        mediaUpdatesSubject.send(mediaItem)
        
        return mediaItem
    }
    
    public func deleteMedia(id: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let mediaItem = mediaItems[id] else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        mediaItems.removeValue(forKey: id)
        mediaData.removeValue(forKey: id)
        accessLogs.removeValue(forKey: id)
        cacheSize -= mediaItem.size
    }
    
    public func getMediaItems(for resourceId: String, resourceType: MediaResourceType) async throws -> [MediaItem] {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return mediaItems.values.filter { 
            $0.resourceId == resourceId && $0.resourceType == resourceType 
        }
    }
    
    // MARK: - Media Processing
    public func generateThumbnail(for mediaId: String) async throws -> UIImage {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard mediaItems[mediaId] != nil else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        // Return a mock thumbnail (1x1 pixel image)
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        return thumbnail
    }
    
    public func processVideo(mediaId: String, settings: VideoProcessingSettings) async throws -> MediaItem {
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        guard var mediaItem = mediaItems[mediaId] else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        // Simulate video processing
        mediaItem.processingStatus = .processing
        mediaItems[mediaId] = mediaItem
        mediaUpdatesSubject.send(mediaItem)
        
        // Simulate processing completion
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        mediaItem.processingStatus = .completed
        mediaItem.updatedAt = Date()
        
        mediaItems[mediaId] = mediaItem
        mediaUpdatesSubject.send(mediaItem)
        
        return mediaItem
    }
    
    public func extractAudioFromVideo(mediaId: String) async throws -> MediaItem {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        guard let videoItem = mediaItems[mediaId], videoItem.type == .video else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        let audioId = UUID().uuidString
        let audioItem = MediaItem(
            id: audioId,
            filename: "extracted_audio_\(audioId).mp3",
            originalFilename: "extracted_\(videoItem.originalFilename).mp3",
            type: .audio,
            mimeType: "audio/mp3",
            size: videoItem.size / 10, // Audio is typically smaller
            duration: videoItem.duration,
            url: "mock://media/\(audioId)",
            metadata: videoItem.metadata,
            accessLevel: videoItem.accessLevel,
            resourceId: videoItem.resourceId,
            resourceType: videoItem.resourceType,
            uploadedBy: videoItem.uploadedBy,
            processingStatus: .completed,
            checksum: "mock-checksum-\(audioId)"
        )
        
        mediaItems[audioId] = audioItem
        mediaData[audioId] = Data() // Mock audio data
        
        mediaUpdatesSubject.send(audioItem)
        return audioItem
    }
    
    public func compressImage(mediaId: String, quality: ImageCompressionQuality) async throws -> MediaItem {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard var mediaItem = mediaItems[mediaId], mediaItem.type == .image else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        // Simulate compression by reducing size
        let compressionRatio = quality.compressionValue
        mediaItem.size = Int64(Double(mediaItem.size) * Double(compressionRatio))
        mediaItem.updatedAt = Date()
        
        mediaItems[mediaId] = mediaItem
        mediaUpdatesSubject.send(mediaItem)
        
        return mediaItem
    }
    
    // MARK: - Media Validation
    public func validateMedia(at url: URL, type: MediaType) async throws -> MediaValidationResult {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        do {
            let data = try Data(contentsOf: url)
            let fileSize = Int64(data.count)
            
            // Check file size limits
            if fileSize > type.maxFileSize {
                return MediaValidationResult(
                    isValid: false,
                    fileSize: fileSize,
                    mimeType: "unknown",
                    errors: ["File size exceeds maximum allowed size of \(type.maxFileSize) bytes"],
                    warnings: []
                )
            }
            
            // Mock MIME type detection
            let mimeType = getMockMimeType(for: url, type: type)
            
            // Check if MIME type is allowed
            if !type.allowedMimeTypes.contains(mimeType) {
                return MediaValidationResult(
                    isValid: false,
                    fileSize: fileSize,
                    mimeType: mimeType,
                    errors: ["MIME type \(mimeType) not allowed for \(type.displayName)"],
                    warnings: []
                )
            }
            
            return MediaValidationResult(
                isValid: true,
                fileSize: fileSize,
                mimeType: mimeType,
                duration: type == .video ? 120.0 : (type == .audio ? 180.0 : nil),
                dimensions: type == .image || type == .video ? MediaDimensions(width: 1920, height: 1080) : nil,
                errors: [],
                warnings: fileSize > (type.maxFileSize / 2) ? ["Large file size may affect performance"] : []
            )
            
        } catch {
            return MediaValidationResult(
                isValid: false,
                fileSize: 0,
                mimeType: "unknown",
                errors: ["Could not read file: \(error.localizedDescription)"],
                warnings: []
            )
        }
    }
    
    public func scanMediaForContent(mediaId: String) async throws -> ContentScanResult {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        guard mediaItems[mediaId] != nil else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        // Mock content scan - always return appropriate content
        return ContentScanResult(
            isAppropriate: true,
            confidence: 0.95,
            flags: [],
            text: "Mock text extraction",
            objects: [
                DetectedObject(name: "person", confidence: 0.9),
                DetectedObject(name: "martial arts", confidence: 0.85)
            ]
        )
    }
    
    // MARK: - Streaming and Playback
    public func getStreamingURL(for mediaId: String, quality: StreamingQuality) async throws -> URL {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard mediaItems[mediaId] != nil else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        await logMediaAccess(mediaId: mediaId, userId: "mock-user", accessType: .stream)
        
        return URL(string: "mock://streaming/\(mediaId)?quality=\(quality.rawValue)")!
    }
    
    public func prefetchMedia(ids: [String]) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        for id in ids {
            guard mediaItems[id] != nil else {
                throw MediaServiceError.mediaNotFound(id: id)
            }
        }
        
        // Simulate prefetching by adding to cache
        print("📦 [MOCK] Prefetched \(ids.count) media items")
    }
    
    public func clearMediaCache() async throws {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        cacheSize = 0
        print("🗑️ [MOCK] Media cache cleared")
    }
    
    public func getCacheSize() async throws -> Int64 {
        return cacheSize
    }
    
    // MARK: - Access Control
    public func checkMediaAccess(mediaId: String, userId: String) async throws -> Bool {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard let mediaItem = mediaItems[mediaId] else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        // Mock access control logic
        switch mediaItem.accessLevel {
        case .publicAccess:
            return true
        case .subscribersOnly:
            return userId != "free-user" // Mock: non-free users can access
        case .instructorsOnly:
            return userId == "instructor-user" || userId == "user1" // Mock instructor
        case .privateAccess:
            return mediaItem.uploadedBy == userId
        }
    }
    
    public func setMediaAccess(mediaId: String, accessLevel: MediaAccessLevel) async throws -> MediaItem {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard var mediaItem = mediaItems[mediaId] else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        mediaItem.accessLevel = accessLevel
        mediaItem.updatedAt = Date()
        
        mediaItems[mediaId] = mediaItem
        mediaUpdatesSubject.send(mediaItem)
        
        return mediaItem
    }
    
    public func getMediaAccessLog(mediaId: String) async throws -> [MediaAccessEvent] {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard mediaItems[mediaId] != nil else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        return accessLogs[mediaId] ?? []
    }
    
    // MARK: - Search and Discovery
    public func searchMedia(query: String, filters: MediaSearchFilters) async throws -> [MediaItem] {
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        let lowercaseQuery = query.lowercased()
        var results = mediaItems.values.filter { mediaItem in
            mediaItem.filename.lowercased().contains(lowercaseQuery) ||
            mediaItem.originalFilename.lowercased().contains(lowercaseQuery) ||
            mediaItem.metadata.title?.lowercased().contains(lowercaseQuery) == true ||
            mediaItem.metadata.description?.lowercased().contains(lowercaseQuery) == true
        }
        
        // Apply filters
        results = results.filter { mediaItem in
            filters.types.contains(mediaItem.type) &&
            filters.resourceTypes.contains(mediaItem.resourceType) &&
            filters.accessLevels.contains(mediaItem.accessLevel)
        }
        
        if let uploadedAfter = filters.uploadedAfter {
            results = results.filter { $0.uploadedAt >= uploadedAfter }
        }
        
        if let uploadedBefore = filters.uploadedBefore {
            results = results.filter { $0.uploadedAt <= uploadedBefore }
        }
        
        if let minSize = filters.minSize {
            results = results.filter { $0.size >= minSize }
        }
        
        if let maxSize = filters.maxSize {
            results = results.filter { $0.size <= maxSize }
        }
        
        if !filters.tags.isEmpty {
            results = results.filter { mediaItem in
                filters.tags.allSatisfy { tag in
                    mediaItem.tags.contains(tag)
                }
            }
        }
        
        if let uploadedBy = filters.uploadedBy {
            results = results.filter { $0.uploadedBy == uploadedBy }
        }
        
        return Array(results)
    }
    
    public func getRecentMedia(limit: Int) async throws -> [MediaItem] {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        let sortedMedia = mediaItems.values.sorted { $0.uploadedAt > $1.uploadedAt }
        return Array(sortedMedia.prefix(limit))
    }
    
    public func getPopularMedia(limit: Int) async throws -> [MediaItem] {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Mock popularity based on access log count
        let popularMedia = mediaItems.values.sorted { mediaItem1, mediaItem2 in
            let accessCount1 = accessLogs[mediaItem1.id]?.count ?? 0
            let accessCount2 = accessLogs[mediaItem2.id]?.count ?? 0
            return accessCount1 > accessCount2
        }
        
        return Array(popularMedia.prefix(limit))
    }
    
    public func getMediaByTag(tag: String) async throws -> [MediaItem] {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return mediaItems.values.filter { $0.tags.contains(tag) }
    }
    
    // MARK: - Mock Helper Methods
    public func clearAllData() {
        mediaItems.removeAll()
        mediaData.removeAll()
        accessLogs.removeAll()
        cacheSize = 0
    }
    
    // MARK: - Private Helper Methods
    private func simulateUploadProgress(mediaId: String, totalBytes: Int64) async {
        let chunks = 10
        let chunkSize = totalBytes / Int64(chunks)
        
        for i in 1...chunks {
            let bytesUploaded = chunkSize * Int64(i)
            let progress = MediaUploadProgress(
                mediaId: mediaId,
                bytesUploaded: bytesUploaded,
                totalBytes: totalBytes
            )
            
            uploadProgressSubject.send(progress)
            
            // Small delay between chunks
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func simulateDownloadProgress(mediaId: String, totalBytes: Int64) async {
        let chunks = 8
        let chunkSize = totalBytes / Int64(chunks)
        
        for i in 1...chunks {
            let bytesDownloaded = chunkSize * Int64(i)
            let progress = MediaDownloadProgress(
                mediaId: mediaId,
                bytesDownloaded: bytesDownloaded,
                totalBytes: totalBytes
            )
            
            downloadProgressSubject.send(progress)
            
            // Small delay between chunks
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
    }
    
    private func logMediaAccess(mediaId: String, userId: String, accessType: MediaAccessEvent.AccessType) async {
        let accessEvent = MediaAccessEvent(
            mediaId: mediaId,
            userId: userId,
            accessType: accessType,
            userAgent: "MockMediaService/1.0",
            ipAddress: "127.0.0.1"
        )
        
        var logs = accessLogs[mediaId] ?? []
        logs.append(accessEvent)
        
        // Keep only last 50 access events per media item
        if logs.count > 50 {
            logs = Array(logs.suffix(50))
        }
        
        accessLogs[mediaId] = logs
    }
    
    private func getMockMimeType(for url: URL, type: MediaType) -> String {
        let extension = url.pathExtension.lowercased()
        
        switch type {
        case .image:
            switch extension {
            case "png": return "image/png"
            case "gif": return "image/gif"
            case "webp": return "image/webp"
            case "heic": return "image/heic"
            default: return "image/jpeg"
            }
        case .video:
            switch extension {
            case "mov": return "video/mov"
            case "avi": return "video/avi"
            case "mkv": return "video/mkv"
            case "webm": return "video/webm"
            default: return "video/mp4"
            }
        case .audio:
            switch extension {
            case "wav": return "audio/wav"
            case "aac": return "audio/aac"
            case "ogg": return "audio/ogg"
            case "m4a": return "audio/m4a"
            default: return "audio/mp3"
            }
        case .document:
            switch extension {
            case "txt": return "text/plain"
            case "doc": return "application/msword"
            case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            default: return "application/pdf"
            }
        }
    }
    
    // MARK: - Sample Data
    private func seedSampleData() {
        let sampleMetadata = MediaMetadata(
            title: "Sample Training Video",
            description: "Demonstration of basic techniques",
            author: "Instructor John",
            keywords: ["kung fu", "training", "basics"]
        )
        
        let sampleVideoItem = MediaItem(
            id: "sample-video-1",
            filename: "basic_techniques.mp4",
            originalFilename: "basic_techniques_demo.mp4",
            type: .video,
            mimeType: "video/mp4",
            size: 25_000_000, // 25MB
            duration: 300.0, // 5 minutes
            dimensions: MediaDimensions(width: 1920, height: 1080),
            url: "mock://media/sample-video-1",
            thumbnailUrl: "mock://thumbnails/sample-video-1",
            metadata: sampleMetadata,
            accessLevel: .subscribersOnly,
            resourceId: "basic-techniques-curriculum",
            resourceType: .curriculumItem,
            uploadedBy: "user1",
            processingStatus: .completed,
            tags: ["techniques", "basics", "demo"],
            checksum: "mock-checksum-video-1"
        )
        
        let sampleImageItem = MediaItem(
            id: "sample-image-1",
            filename: "stance_diagram.jpg",
            originalFilename: "horse_stance_diagram.jpg",
            type: .image,
            mimeType: "image/jpeg",
            size: 2_000_000, // 2MB
            dimensions: MediaDimensions(width: 1024, height: 768),
            url: "mock://media/sample-image-1",
            thumbnailUrl: "mock://thumbnails/sample-image-1",
            metadata: MediaMetadata(
                title: "Horse Stance Diagram",
                description: "Proper positioning for horse stance",
                author: "Instructor John",
                keywords: ["stance", "diagram", "reference"]
            ),
            accessLevel: .publicAccess,
            resourceId: "stances-curriculum",
            resourceType: .curriculumItem,
            uploadedBy: "user1",
            processingStatus: .completed,
            tags: ["stances", "reference", "diagram"],
            checksum: "mock-checksum-image-1"
        )
        
        mediaItems["sample-video-1"] = sampleVideoItem
        mediaItems["sample-image-1"] = sampleImageItem
        
        // Mock data for sample media
        mediaData["sample-video-1"] = Data(count: 25_000_000)
        mediaData["sample-image-1"] = Data(count: 2_000_000)
        
        cacheSize = 27_000_000 // Total of sample data
        
        // Sample access logs
        accessLogs["sample-video-1"] = [
            MediaAccessEvent(mediaId: "sample-video-1", userId: "user2", accessType: .view),
            MediaAccessEvent(mediaId: "sample-video-1", userId: "user3", accessType: .stream)
        ]
        
        accessLogs["sample-image-1"] = [
            MediaAccessEvent(mediaId: "sample-image-1", userId: "user2", accessType: .view),
            MediaAccessEvent(mediaId: "sample-image-1", userId: "user3", accessType: .view),
            MediaAccessEvent(mediaId: "sample-image-1", userId: "user1", accessType: .download)
        ]
    }
}