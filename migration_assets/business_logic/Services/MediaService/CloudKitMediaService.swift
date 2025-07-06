import Foundation
import Combine
import CloudKit
import FirebaseStorage
import UIKit

// MARK: - CloudKit Media Service Implementation
public final class CloudKitMediaService: MediaService {
    
    // MARK: - CloudKit Configuration
    private let container: CKContainer
    private let database: CKDatabase
    private let recordZone: CKRecordZone
    
    // MARK: - Firebase Storage Configuration
    private let storage: Storage
    private let storageRef: StorageReference
    
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
    
    // MARK: - Cache Management
    private var mediaCache: [String: MediaItem] = [:]
    private var dataCache: [String: Data] = [:]
    private var cacheSize: Int64 = 0
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let cacheQueue = DispatchQueue(label: "com.sakungfujournal.mediaservice.cache", attributes: .concurrent)
    
    // MARK: - Upload Progress Tracking
    private var activeUploads: [String: URLSessionUploadTask] = [:]
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]
    
    // MARK: - Record Types
    private struct RecordType {
        static let mediaItem = "MediaItem"
        static let mediaMetadata = "MediaMetadata"
        static let accessEvent = "MediaAccessEvent"
    }
    
    // MARK: - Initialization
    public init(
        container: CKContainer? = nil,
        storage: Storage = Storage.storage()
    ) {
        self.container = container ?? CKContainer(identifier: "iCloud.com.sakungfujournal")
        self.database = self.container.privateCloudDatabase
        self.recordZone = CKRecordZone(zoneName: "MediaDataZone")
        self.storage = storage
        self.storageRef = storage.reference()
        
        setupCloudKit()
    }
    
    // MARK: - CloudKit Setup
    private func setupCloudKit() {
        Task {
            await createCustomZoneIfNeeded()
        }
    }
    
    private func createCustomZoneIfNeeded() async {
        do {
            let _ = try await database.save(recordZone)
            print("✅ [CloudKitMedia] Custom zone created/verified")
        } catch let error as CKError where error.code == .serverRecordChanged {
            print("✅ [CloudKitMedia] Custom zone already exists")
        } catch {
            print("❌ [CloudKitMedia] Failed to create custom zone: \(error)")
        }
    }
    
    // MARK: - Media Upload
    public func uploadImage(_ image: UIImage, metadata: MediaMetadata) async throws -> MediaItem {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw MediaServiceError.processingFailed(reason: "Failed to convert image to JPEG data")
        }
        
        return try await uploadData(imageData, type: .image, metadata: metadata)
    }
    
    public func uploadVideo(from url: URL, metadata: MediaMetadata) async throws -> MediaItem {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MediaServiceError.uploadFailed(reason: "File not found at path: \(url.path)")
        }
        
        let videoData = try Data(contentsOf: url)
        return try await uploadData(videoData, type: .video, metadata: metadata)
    }
    
    public func uploadAudio(from url: URL, metadata: MediaMetadata) async throws -> MediaItem {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MediaServiceError.uploadFailed(reason: "File not found at path: \(url.path)")
        }
        
        let audioData = try Data(contentsOf: url)
        return try await uploadData(audioData, type: .audio, metadata: metadata)
    }
    
    public func uploadDocument(from url: URL, metadata: MediaMetadata) async throws -> MediaItem {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MediaServiceError.uploadFailed(reason: "File not found at path: \(url.path)")
        }
        
        let documentData = try Data(contentsOf: url)
        return try await uploadData(documentData, type: .document, metadata: metadata)
    }
    
    // MARK: - Private Upload Implementation
    private func uploadData(_ data: Data, type: MediaType, metadata: MediaMetadata) async throws -> MediaItem {
        let mediaId = UUID().uuidString
        let fileExtension = type.defaultFileExtension
        let filename = "\(mediaId).\(fileExtension)"
        let originalFilename = metadata.originalFilename ?? filename
        
        do {
            // Upload to Firebase Storage
            let storageRef = self.storageRef.child("media/\(filename)")
            
            // Create upload progress tracking
            let progressHandler: (Progress) -> Void = { [weak self] progress in
                let uploadProgress = MediaUploadProgress(
                    mediaId: mediaId,
                    filename: filename,
                    bytesUploaded: progress.completedUnitCount,
                    totalBytes: progress.totalUnitCount,
                    progress: progress.fractionCompleted,
                    isComplete: progress.isFinished
                )
                self?.uploadProgressSubject.send(uploadProgress)
            }
            
            // Upload data with progress tracking
            let uploadTask = storageRef.putData(data, metadata: nil) { _, error in
                if let error = error {
                    print("❌ [CloudKitMedia] Firebase upload failed: \(error)")
                }
            }
            
            // Track upload progress
            uploadTask.observe(.progress, handler: { snapshot in
                if let progress = snapshot.progress {
                    progressHandler(progress)
                }
            })
            
            // Wait for upload completion
            let _ = try await uploadTask
            
            // Get download URL
            let downloadURL = try await storageRef.downloadURL()
            
            // Create MediaItem
            let mediaItem = MediaItem(
                id: mediaId,
                filename: filename,
                originalFilename: originalFilename,
                type: type,
                mimeType: type.defaultMimeType,
                size: Int64(data.count),
                url: downloadURL.absoluteString,
                thumbnailURL: nil, // Will be generated if needed
                duration: nil, // Would be extracted for audio/video
                width: type == .image ? extractImageWidth(from: data) : nil,
                height: type == .image ? extractImageHeight(from: data) : nil,
                metadata: metadata,
                uploadedAt: Date(),
                uploadedBy: metadata.uploadedBy,
                accessLevel: metadata.accessLevel,
                isActive: true
            )
            
            // Save metadata to CloudKit
            try await saveMediaItemToCloudKit(mediaItem)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.mediaCache[mediaId] = mediaItem
                self.dataCache[mediaId] = data
                self.cacheSize += Int64(data.count)
                self.cleanupCacheIfNeeded()
            }
            
            // Notify subscribers
            mediaUpdatesSubject.send(mediaItem)
            
            // Record access event
            await recordAccessEvent(mediaId: mediaId, eventType: .upload, userId: metadata.uploadedBy)
            
            return mediaItem
            
        } catch {
            throw convertStorageError(error)
        }
    }
    
    // MARK: - Media Retrieval
    public func getMediaItem(id: String) async throws -> MediaItem? {
        // Check cache first
        if let cachedItem = await getCachedMediaItem(id: id) {
            return cachedItem
        }
        
        do {
            let recordID = CKRecord.ID(recordName: id, zoneID: recordZone.zoneID)
            let record = try await database.record(for: recordID)
            
            let mediaItem = try createMediaItem(from: record)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.mediaCache[id] = mediaItem
            }
            
            return mediaItem
            
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw convertCloudKitError(error)
        }
    }
    
    public func getMediaData(id: String) async throws -> Data {
        // Check cache first
        if let cachedData = await getCachedData(id: id) {
            await recordAccessEvent(mediaId: id, eventType: .download, userId: getCurrentUserId())
            return cachedData
        }
        
        guard let mediaItem = try await getMediaItem(id: id) else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        guard let urlString = mediaItem.url, let url = URL(string: urlString) else {
            throw MediaServiceError.invalidURL(url: mediaItem.url ?? "")
        }
        
        do {
            // Download from Firebase Storage
            let storageRef = storage.reference(forURL: urlString)
            
            let downloadProgress = MediaDownloadProgress(
                mediaId: id,
                filename: mediaItem.filename,
                bytesDownloaded: 0,
                totalBytes: mediaItem.size,
                progress: 0.0,
                isComplete: false
            )
            downloadProgressSubject.send(downloadProgress)
            
            let data = try await storageRef.data(maxSize: 50 * 1024 * 1024) // 50MB max
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.dataCache[id] = data
                self.cacheSize += Int64(data.count)
                self.cleanupCacheIfNeeded()
            }
            
            // Send completion progress
            let completedProgress = MediaDownloadProgress(
                mediaId: id,
                filename: mediaItem.filename,
                bytesDownloaded: Int64(data.count),
                totalBytes: mediaItem.size,
                progress: 1.0,
                isComplete: true
            )
            downloadProgressSubject.send(completedProgress)
            
            // Record access event
            await recordAccessEvent(mediaId: id, eventType: .download, userId: getCurrentUserId())
            
            return data
            
        } catch {
            throw convertStorageError(error)
        }
    }
    
    public func getMediaURL(id: String) async throws -> URL {
        guard let mediaItem = try await getMediaItem(id: id) else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        guard let urlString = mediaItem.url, let url = URL(string: urlString) else {
            throw MediaServiceError.invalidURL(url: mediaItem.url ?? "")
        }
        
        // Record access event
        await recordAccessEvent(mediaId: id, eventType: .stream, userId: getCurrentUserId())
        
        return url
    }
    
    public func getMediaThumbnail(id: String, size: CGSize) async throws -> Data {
        guard let mediaItem = try await getMediaItem(id: id) else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        // Check if thumbnail already exists
        if let thumbnailURL = mediaItem.thumbnailURL,
           let url = URL(string: thumbnailURL) {
            let storageRef = storage.reference(forURL: thumbnailURL)
            return try await storageRef.data(maxSize: 5 * 1024 * 1024) // 5MB max for thumbnails
        }
        
        // Generate thumbnail if media is an image or video
        switch mediaItem.type {
        case .image:
            let originalData = try await getMediaData(id: id)
            guard let originalImage = UIImage(data: originalData) else {
                throw MediaServiceError.thumbnailGenerationFailed(id: id)
            }
            
            let thumbnail = generateImageThumbnail(image: originalImage, size: size)
            guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
                throw MediaServiceError.thumbnailGenerationFailed(id: id)
            }
            
            // Upload thumbnail to storage
            let thumbnailFilename = "thumb_\(id).jpg"
            let thumbnailRef = storageRef.child("thumbnails/\(thumbnailFilename)")
            try await thumbnailRef.putDataAsync(thumbnailData)
            let thumbnailURL = try await thumbnailRef.downloadURL()
            
            // Update media item with thumbnail URL
            var updatedItem = mediaItem
            updatedItem.thumbnailURL = thumbnailURL.absoluteString
            try await updateMediaItemInCloudKit(updatedItem)
            
            return thumbnailData
            
        case .video:
            // Video thumbnail generation would require additional video processing libraries
            throw MediaServiceError.thumbnailGenerationNotSupported(type: mediaItem.type)
            
        case .audio, .document:
            throw MediaServiceError.thumbnailGenerationNotSupported(type: mediaItem.type)
        }
    }
    
    // MARK: - Media Management
    public func updateMediaMetadata(id: String, metadata: MediaMetadata) async throws -> MediaItem {
        guard var mediaItem = try await getMediaItem(id: id) else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        mediaItem.metadata = metadata
        try await updateMediaItemInCloudKit(mediaItem)
        
        // Update cache
        cacheQueue.async(flags: .barrier) {
            self.mediaCache[id] = mediaItem
        }
        
        // Notify subscribers
        mediaUpdatesSubject.send(mediaItem)
        
        return mediaItem
    }
    
    public func deleteMedia(id: String) async throws {
        guard let mediaItem = try await getMediaItem(id: id) else {
            throw MediaServiceError.mediaNotFound(id: id)
        }
        
        do {
            // Delete from Firebase Storage
            if let urlString = mediaItem.url {
                let storageRef = storage.reference(forURL: urlString)
                try await storageRef.delete()
            }
            
            // Delete thumbnail if exists
            if let thumbnailURL = mediaItem.thumbnailURL {
                let thumbnailRef = storage.reference(forURL: thumbnailURL)
                try? await thumbnailRef.delete() // Non-critical if fails
            }
            
            // Delete from CloudKit
            let recordID = CKRecord.ID(recordName: id, zoneID: recordZone.zoneID)
            try await database.deleteRecord(withID: recordID)
            
            // Remove from cache
            cacheQueue.async(flags: .barrier) {
                self.mediaCache.removeValue(forKey: id)
                if let data = self.dataCache.removeValue(forKey: id) {
                    self.cacheSize -= Int64(data.count)
                }
            }
            
            // Record access event
            await recordAccessEvent(mediaId: id, eventType: .delete, userId: getCurrentUserId())
            
        } catch {
            throw convertStorageError(error)
        }
    }
    
    // MARK: - Media Search and Listing
    public func searchMedia(query: String, filters: MediaSearchFilters) async throws -> [MediaItem] {
        do {
            var predicate: NSPredicate
            
            if let type = filters.type {
                predicate = NSPredicate(format: "type == %@ AND (filename CONTAINS[cd] %@ OR originalFilename CONTAINS[cd] %@)", 
                                      type.rawValue, query, query)
            } else {
                predicate = NSPredicate(format: "filename CONTAINS[cd] %@ OR originalFilename CONTAINS[cd] %@", 
                                      query, query)
            }
            
            let ckQuery = CKQuery(recordType: RecordType.mediaItem, predicate: predicate)
            ckQuery.sortDescriptors = [NSSortDescriptor(key: "uploadedAt", ascending: false)]
            
            let (matchResults, _) = try await database.records(matching: ckQuery, inZoneWith: recordZone.zoneID)
            
            var mediaItems: [MediaItem] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let mediaItem = try? createMediaItem(from: record) {
                        mediaItems.append(mediaItem)
                        
                        // Update cache
                        cacheQueue.async(flags: .barrier) {
                            self.mediaCache[mediaItem.id] = mediaItem
                        }
                    }
                case .failure:
                    continue
                }
            }
            
            return Array(mediaItems.prefix(filters.limit ?? 50))
            
        } catch {
            throw convertCloudKitError(error)
        }
    }
    
    public func getMediaByType(_ type: MediaType, limit: Int) async throws -> [MediaItem] {
        do {
            let predicate = NSPredicate(format: "type == %@ AND isActive == 1", type.rawValue)
            let ckQuery = CKQuery(recordType: RecordType.mediaItem, predicate: predicate)
            ckQuery.sortDescriptors = [NSSortDescriptor(key: "uploadedAt", ascending: false)]
            
            let (matchResults, _) = try await database.records(matching: ckQuery, inZoneWith: recordZone.zoneID)
            
            var mediaItems: [MediaItem] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let mediaItem = try? createMediaItem(from: record) {
                        mediaItems.append(mediaItem)
                        
                        // Update cache
                        cacheQueue.async(flags: .barrier) {
                            self.mediaCache[mediaItem.id] = mediaItem
                        }
                    }
                case .failure:
                    continue
                }
            }
            
            return Array(mediaItems.prefix(limit))
            
        } catch {
            throw convertCloudKitError(error)
        }
    }
    
    public func getMediaByUploader(userId: String, limit: Int) async throws -> [MediaItem] {
        do {
            let predicate = NSPredicate(format: "uploadedBy == %@ AND isActive == 1", userId)
            let ckQuery = CKQuery(recordType: RecordType.mediaItem, predicate: predicate)
            ckQuery.sortDescriptors = [NSSortDescriptor(key: "uploadedAt", ascending: false)]
            
            let (matchResults, _) = try await database.records(matching: ckQuery, inZoneWith: recordZone.zoneID)
            
            var mediaItems: [MediaItem] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let mediaItem = try? createMediaItem(from: record) {
                        mediaItems.append(mediaItem)
                        
                        // Update cache
                        cacheQueue.async(flags: .barrier) {
                            self.mediaCache[mediaItem.id] = mediaItem
                        }
                    }
                case .failure:
                    continue
                }
            }
            
            return Array(mediaItems.prefix(limit))
            
        } catch {
            throw convertCloudKitError(error)
        }
    }
    
    public func getRecentMedia(limit: Int) async throws -> [MediaItem] {
        do {
            let predicate = NSPredicate(format: "isActive == 1")
            let ckQuery = CKQuery(recordType: RecordType.mediaItem, predicate: predicate)
            ckQuery.sortDescriptors = [NSSortDescriptor(key: "uploadedAt", ascending: false)]
            
            let (matchResults, _) = try await database.records(matching: ckQuery, inZoneWith: recordZone.zoneID)
            
            var mediaItems: [MediaItem] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let mediaItem = try? createMediaItem(from: record) {
                        mediaItems.append(mediaItem)
                        
                        // Update cache
                        cacheQueue.async(flags: .barrier) {
                            self.mediaCache[mediaItem.id] = mediaItem
                        }
                    }
                case .failure:
                    continue
                }
            }
            
            return Array(mediaItems.prefix(limit))
            
        } catch {
            throw convertCloudKitError(error)
        }
    }
    
    // MARK: - Access Control and Analytics
    public func checkAccess(mediaId: String, userId: String) async throws -> Bool {
        guard let mediaItem = try await getMediaItem(id: mediaId) else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        switch mediaItem.accessLevel {
        case .public:
            return true
        case .authenticated:
            return !userId.isEmpty
        case .restricted:
            // Would require additional permission checking logic
            return mediaItem.uploadedBy == userId
        case .private:
            return mediaItem.uploadedBy == userId
        }
    }
    
    public func getMediaAnalytics(mediaId: String) async throws -> MediaAnalytics {
        guard let mediaItem = try await getMediaItem(id: mediaId) else {
            throw MediaServiceError.mediaNotFound(id: mediaId)
        }
        
        // Get access events from CloudKit
        let accessEvents = try await getAccessEvents(mediaId: mediaId)
        
        let totalViews = accessEvents.filter { $0.eventType == .download || $0.eventType == .stream }.count
        let uniqueViewers = Set(accessEvents.map { $0.userId }).count
        
        return MediaAnalytics(
            mediaId: mediaId,
            totalViews: totalViews,
            uniqueViewers: uniqueViewers,
            downloadCount: accessEvents.filter { $0.eventType == .download }.count,
            streamCount: accessEvents.filter { $0.eventType == .stream }.count,
            lastAccessed: accessEvents.map { $0.timestamp }.max(),
            popularityScore: calculatePopularityScore(totalViews: totalViews, uniqueViewers: uniqueViewers, uploadDate: mediaItem.uploadedAt),
            accessEvents: accessEvents
        )
    }
    
    public func getStorageQuota() async throws -> StorageQuota {
        // This would require implementing storage usage tracking
        // For now, return a mock quota
        return StorageQuota(
            totalSpace: 5 * 1024 * 1024 * 1024, // 5GB
            usedSpace: 1 * 1024 * 1024 * 1024, // 1GB used
            availableSpace: 4 * 1024 * 1024 * 1024, // 4GB available
            mediaCount: mediaCache.count,
            cacheSize: cacheSize,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Cache Management
    public func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.mediaCache.removeAll()
            self.dataCache.removeAll()
            self.cacheSize = 0
        }
    }
    
    public func preloadMedia(ids: [String]) async throws {
        for id in ids {
            if !await isCached(id: id) {
                try? await getMediaData(id: id) // Load into cache
            }
        }
    }
    
    // MARK: - Missing Protocol Methods (Stub Implementations)
    
    public func downloadMedia(id: String) async throws -> Data {
        return try await getMediaData(id: id)
    }
    
    public func downloadMediaToFile(id: String, destinationURL: URL) async throws -> URL {
        let data = try await getMediaData(id: id)
        try data.write(to: destinationURL)
        return destinationURL
    }
    
    public func getCachedMediaURL(id: String) -> URL? {
        return nil // Not implemented for CloudKit storage
    }
    
    public func getMediaItems(for resourceId: String, resourceType: MediaResourceType) async throws -> [MediaItem] {
        throw MediaServiceError.notImplemented
    }
    
    public func generateThumbnail(for mediaId: String) async throws -> UIImage {
        let data = try await getMediaThumbnail(id: mediaId, size: CGSize(width: 200, height: 200))
        guard let image = UIImage(data: data) else {
            throw MediaServiceError.thumbnailGenerationFailed(id: mediaId)
        }
        return image
    }
    
    public func processVideo(mediaId: String, settings: VideoProcessingSettings) async throws -> MediaItem {
        throw MediaServiceError.notImplemented
    }
    
    public func extractAudioFromVideo(mediaId: String) async throws -> MediaItem {
        throw MediaServiceError.notImplemented
    }
    
    public func compressImage(mediaId: String, quality: ImageCompressionQuality) async throws -> MediaItem {
        throw MediaServiceError.notImplemented
    }
    
    public func validateMedia(at url: URL, type: MediaType) async throws -> MediaValidationResult {
        throw MediaServiceError.notImplemented
    }
    
    public func scanMediaForContent(mediaId: String) async throws -> ContentScanResult {
        throw MediaServiceError.notImplemented
    }
    
    public func getStreamingURL(for mediaId: String, quality: StreamingQuality) async throws -> URL {
        return try await getMediaURL(id: mediaId)
    }
    
    public func prefetchMedia(ids: [String]) async throws {
        try await preloadMedia(ids: ids)
    }
    
    public func clearMediaCache() async throws {
        clearCache()
    }
    
    public func getCacheSize() async throws -> Int64 {
        return cacheSize
    }
    
    public func checkMediaAccess(mediaId: String, userId: String) async throws -> Bool {
        return try await checkAccess(mediaId: mediaId, userId: userId)
    }
    
    public func setMediaAccess(mediaId: String, accessLevel: MediaAccessLevel) async throws -> MediaItem {
        throw MediaServiceError.notImplemented
    }
    
    public func getMediaAccessLog(mediaId: String) async throws -> [MediaAccessEvent] {
        return try await getAccessEvents(mediaId: mediaId)
    }
    
    public func getPopularMedia(limit: Int) async throws -> [MediaItem] {
        return try await getRecentMedia(limit: limit)
    }
    
    public func getMediaByTag(tag: String) async throws -> [MediaItem] {
        throw MediaServiceError.notImplemented
    }
    
    // MARK: - Private Helper Methods
    private func saveMediaItemToCloudKit(_ mediaItem: MediaItem) async throws {
        let record = createMediaItemRecord(from: mediaItem)
        try await database.save(record)
    }
    
    private func updateMediaItemInCloudKit(_ mediaItem: MediaItem) async throws {
        do {
            let recordID = CKRecord.ID(recordName: mediaItem.id, zoneID: recordZone.zoneID)
            let record = try await database.record(for: recordID)
            updateMediaItemRecord(record, with: mediaItem)
            try await database.save(record)
        } catch {
            throw convertCloudKitError(error)
        }
    }
    
    private func createMediaItemRecord(from mediaItem: MediaItem) -> CKRecord {
        let recordID = CKRecord.ID(recordName: mediaItem.id, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.mediaItem, recordID: recordID)
        
        record["filename"] = mediaItem.filename
        record["originalFilename"] = mediaItem.originalFilename
        record["type"] = mediaItem.type.rawValue
        record["mimeType"] = mediaItem.mimeType
        record["size"] = mediaItem.size
        record["url"] = mediaItem.url
        record["thumbnailURL"] = mediaItem.thumbnailURL
        record["duration"] = mediaItem.duration
        record["width"] = mediaItem.width
        record["height"] = mediaItem.height
        record["uploadedAt"] = mediaItem.uploadedAt
        record["uploadedBy"] = mediaItem.uploadedBy
        record["accessLevel"] = mediaItem.accessLevel.rawValue
        record["isActive"] = mediaItem.isActive ? 1 : 0
        
        // Store metadata as JSON
        if let metadataData = try? JSONEncoder().encode(mediaItem.metadata) {
            record["metadata"] = metadataData
        }
        
        return record
    }
    
    private func updateMediaItemRecord(_ record: CKRecord, with mediaItem: MediaItem) {
        record["filename"] = mediaItem.filename
        record["originalFilename"] = mediaItem.originalFilename
        record["type"] = mediaItem.type.rawValue
        record["mimeType"] = mediaItem.mimeType
        record["size"] = mediaItem.size
        record["url"] = mediaItem.url
        record["thumbnailURL"] = mediaItem.thumbnailURL
        record["duration"] = mediaItem.duration
        record["width"] = mediaItem.width
        record["height"] = mediaItem.height
        record["uploadedBy"] = mediaItem.uploadedBy
        record["accessLevel"] = mediaItem.accessLevel.rawValue
        record["isActive"] = mediaItem.isActive ? 1 : 0
        
        // Store metadata as JSON
        if let metadataData = try? JSONEncoder().encode(mediaItem.metadata) {
            record["metadata"] = metadataData
        }
    }
    
    private func createMediaItem(from record: CKRecord) throws -> MediaItem {
        guard let filename = record["filename"] as? String,
              let originalFilename = record["originalFilename"] as? String,
              let typeString = record["type"] as? String,
              let type = MediaType(rawValue: typeString),
              let mimeType = record["mimeType"] as? String,
              let size = record["size"] as? Int64,
              let uploadedAt = record["uploadedAt"] as? Date,
              let uploadedBy = record["uploadedBy"] as? String,
              let accessLevelString = record["accessLevel"] as? String,
              let accessLevel = AccessLevel(rawValue: accessLevelString),
              let isActiveInt = record["isActive"] as? Int else {
            throw MediaServiceError.invalidMediaData(field: "required fields")
        }
        
        let url = record["url"] as? String
        let thumbnailURL = record["thumbnailURL"] as? String
        let duration = record["duration"] as? Double
        let width = record["width"] as? Int
        let height = record["height"] as? Int
        let isActive = isActiveInt == 1
        
        // Decode metadata
        var metadata = MediaMetadata(originalFilename: originalFilename, uploadedBy: uploadedBy, accessLevel: accessLevel)
        if let metadataData = record["metadata"] as? Data {
            metadata = (try? JSONDecoder().decode(MediaMetadata.self, from: metadataData)) ?? metadata
        }
        
        return MediaItem(
            id: record.recordID.recordName,
            filename: filename,
            originalFilename: originalFilename,
            type: type,
            mimeType: mimeType,
            size: size,
            url: url,
            thumbnailURL: thumbnailURL,
            duration: duration,
            width: width,
            height: height,
            metadata: metadata,
            uploadedAt: uploadedAt,
            uploadedBy: uploadedBy,
            accessLevel: accessLevel,
            isActive: isActive
        )
    }
    
    private func recordAccessEvent(mediaId: String, eventType: AccessEventType, userId: String) async {
        let event = MediaAccessEvent(
            mediaId: mediaId,
            userId: userId,
            eventType: eventType,
            timestamp: Date(),
            metadata: [:]
        )
        
        let record = createAccessEventRecord(from: event)
        
        do {
            try await database.save(record)
        } catch {
            print("❌ [CloudKitMedia] Failed to record access event: \(error)")
        }
    }
    
    private func createAccessEventRecord(from event: MediaAccessEvent) -> CKRecord {
        let recordID = CKRecord.ID(recordName: event.id.uuidString, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.accessEvent, recordID: recordID)
        
        record["mediaId"] = event.mediaId
        record["userId"] = event.userId
        record["eventType"] = event.eventType.rawValue
        record["timestamp"] = event.timestamp
        
        if let metadataData = try? JSONSerialization.data(withJSONObject: event.metadata) {
            record["metadata"] = metadataData
        }
        
        return record
    }
    
    private func getAccessEvents(mediaId: String) async throws -> [MediaAccessEvent] {
        let predicate = NSPredicate(format: "mediaId == %@", mediaId)
        let ckQuery = CKQuery(recordType: RecordType.accessEvent, predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let (matchResults, _) = try await database.records(matching: ckQuery, inZoneWith: recordZone.zoneID)
        
        var events: [MediaAccessEvent] = []
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let event = createAccessEvent(from: record) {
                    events.append(event)
                }
            case .failure:
                continue
            }
        }
        
        return events
    }
    
    private func createAccessEvent(from record: CKRecord) -> MediaAccessEvent? {
        guard let mediaId = record["mediaId"] as? String,
              let userId = record["userId"] as? String,
              let eventTypeString = record["eventType"] as? String,
              let eventType = AccessEventType(rawValue: eventTypeString),
              let timestamp = record["timestamp"] as? Date else {
            return nil
        }
        
        var metadata: [String: Any] = [:]
        if let metadataData = record["metadata"] as? Data {
            metadata = (try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any]) ?? [:]
        }
        
        return MediaAccessEvent(
            mediaId: mediaId,
            userId: userId,
            eventType: eventType,
            timestamp: timestamp,
            metadata: metadata
        )
    }
    
    private func getCachedMediaItem(id: String) async -> MediaItem? {
        return await cacheQueue.sync {
            return mediaCache[id]
        }
    }
    
    private func getCachedData(id: String) async -> Data? {
        return await cacheQueue.sync {
            return dataCache[id]
        }
    }
    
    private func isCached(id: String) async -> Bool {
        return await cacheQueue.sync {
            return dataCache[id] != nil
        }
    }
    
    private func cleanupCacheIfNeeded() {
        guard cacheSize > maxCacheSize else { return }
        
        // Remove oldest cached data until under limit
        let sortedKeys = dataCache.keys.sorted { key1, key2 in
            let item1 = mediaCache[key1]
            let item2 = mediaCache[key2]
            return (item1?.uploadedAt ?? Date.distantPast) < (item2?.uploadedAt ?? Date.distantPast)
        }
        
        for key in sortedKeys {
            if let data = dataCache.removeValue(forKey: key) {
                cacheSize -= Int64(data.count)
                if cacheSize <= maxCacheSize * 3 / 4 { // Stop at 75% of max
                    break
                }
            }
        }
    }
    
    private func generateImageThumbnail(image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func extractImageWidth(from data: Data) -> Int? {
        guard let image = UIImage(data: data) else { return nil }
        return Int(image.size.width)
    }
    
    private func extractImageHeight(from data: Data) -> Int? {
        guard let image = UIImage(data: data) else { return nil }
        return Int(image.size.height)
    }
    
    private func calculatePopularityScore(totalViews: Int, uniqueViewers: Int, uploadDate: Date) -> Double {
        let daysSinceUpload = Date().timeIntervalSince(uploadDate) / (24 * 3600)
        let recencyFactor = max(0.1, 1.0 - (daysSinceUpload / 365.0)) // Decay over a year
        
        return Double(totalViews + uniqueViewers * 2) * recencyFactor
    }
    
    private func getCurrentUserId() -> String {
        // Would integrate with AuthService to get current user
        return "current-user"
    }
    
    private func convertCloudKitError(_ error: Error) -> MediaServiceError {
        guard let ckError = error as? CKError else {
            return .unknown(underlying: error)
        }
        
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return .networkError(underlying: error)
        case .notAuthenticated:
            return .insufficientPermissions(operation: "CloudKit access")
        case .quotaExceeded:
            return .storageQuotaExceeded
        case .recordSizeExceeded:
            return .fileSizeLimitExceeded(size: 0) // Would need actual size
        default:
            return .unknown(underlying: error)
        }
    }
    
    private func convertStorageError(_ error: Error) -> MediaServiceError {
        if let storageError = error as NSError? {
            switch storageError.code {
            case StorageErrorCode.objectNotFound.rawValue:
                return .mediaNotFound(id: "")
            case StorageErrorCode.unauthorized.rawValue:
                return .insufficientPermissions(operation: "Firebase Storage access")
            case StorageErrorCode.quotaExceeded.rawValue:
                return .storageQuotaExceeded
            case StorageErrorCode.downloadSizeExceeded.rawValue:
                return .fileSizeLimitExceeded(size: 0)
            default:
                return .unknown(underlying: error)
            }
        }
        return .unknown(underlying: error)
    }
}

// MARK: - MediaType Extensions
extension MediaType {
    var defaultFileExtension: String {
        switch self {
        case .image:
            return "jpg"
        case .video:
            return "mp4"
        case .audio:
            return "mp3"
        case .document:
            return "pdf"
        }
    }
    
    var defaultMimeType: String {
        switch self {
        case .image:
            return "image/jpeg"
        case .video:
            return "video/mp4"
        case .audio:
            return "audio/mpeg"
        case .document:
            return "application/pdf"
        }
    }
}

// MARK: - Firebase Storage Extensions
extension StorageReference {
    func putDataAsync(_ uploadData: Data, metadata: StorageMetadata? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.putData(uploadData, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Temporary Error Type
extension MediaServiceError {
    static let notImplemented = MediaServiceError.unknown(underlying: NSError(domain: "MediaService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]))
}