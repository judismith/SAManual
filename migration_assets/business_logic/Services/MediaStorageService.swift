import Foundation
import CloudKit
import UIKit

class MediaStorageService: ObservableObject {
    static let shared = MediaStorageService()
    
    private let cloudKitService = CloudKitService.shared
    
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var errorMessage: String?
    
    // MARK: - Upload Methods
    
    func uploadUserMedia(image: UIImage, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to convert image to data"
            isUploading = false
            completion(.failure(MediaStorageError.imageConversionFailed))
            return
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let recordName = "\(userId)_\(fileName)"
        
        // Upload to user's private iCloud storage
        uploadToUserPrivateStorage(imageData: imageData, recordName: recordName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isUploading = false
                switch result {
                case .success(let url):
                    completion(.success(url))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    func uploadFreeContentMedia(image: UIImage, contentId: String, completion: @escaping (Result<String, Error>) -> Void) {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to convert image to data"
            isUploading = false
            completion(.failure(MediaStorageError.imageConversionFailed))
            return
        }
        
        let fileName = "\(contentId)_\(UUID().uuidString).jpg"
        
        // Upload to app's public iCloud bucket
        uploadToAppPublicStorage(imageData: imageData, fileName: fileName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isUploading = false
                switch result {
                case .success(let url):
                    completion(.success(url))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    func uploadSubscriptionContentMedia(image: UIImage, contentId: String, completion: @escaping (Result<String, Error>) -> Void) {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to convert image to data"
            isUploading = false
            completion(.failure(MediaStorageError.imageConversionFailed))
            return
        }
        
        let fileName = "\(contentId)_\(UUID().uuidString).jpg"
        
        // Upload to app's public iCloud bucket (same as free content)
        uploadToAppPublicStorage(imageData: imageData, fileName: fileName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isUploading = false
                switch result {
                case .success(let url):
                    completion(.success(url))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Private Upload Methods
    
    private func uploadToUserPrivateStorage(imageData: Data, recordName: String, completion: @escaping (Result<String, Error>) -> Void) {
        let record = CKRecord(recordType: "UserMedia")
        record.setValue(imageData, forKey: "imageData")
        record.setValue("image/jpeg", forKey: "contentType")
        
        cloudKitService.privateDatabase.save(record) { record, error in
            if let error = error {
                completion(.failure(error))
            } else if let record = record {
                let url = "icloud://user_private/\(record.recordID.recordName)"
                completion(.success(url))
            } else {
                completion(.failure(MediaStorageError.uploadFailed))
            }
        }
    }
    
    private func uploadToAppPublicStorage(imageData: Data, fileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        let record = CKRecord(recordType: "PublicMedia")
        record.setValue(imageData, forKey: "imageData")
        record.setValue("image/jpeg", forKey: "contentType")
        record.setValue(fileName, forKey: "fileName")
        
        cloudKitService.publicDatabase.save(record) { record, error in
            if let error = error {
                completion(.failure(error))
            } else if let record = record {
                let url = "icloud://app_public/\(record.recordID.recordName)"
                completion(.success(url))
            } else {
                completion(.failure(MediaStorageError.uploadFailed))
            }
        }
    }
    
    // MARK: - Download Methods
    
    func downloadMedia(from url: String, storageLocation: MediaStorageLocation, completion: @escaping (Result<UIImage, Error>) -> Void) {
        switch storageLocation {
        case .userPrivate:
            downloadFromUserPrivateStorage(url: url, completion: completion)
        case .appPublic:
            downloadFromAppPublicStorage(url: url, completion: completion)
        }
    }
    
    private func downloadFromUserPrivateStorage(url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        // Extract record name from URL
        let components = url.components(separatedBy: "/")
        guard let recordName = components.last else {
            print("❌ [MediaStorageService] Invalid URL format for user private: \(url)")
            completion(.failure(MediaStorageError.invalidUrl))
            return
        }
        
        print("🔄 [MediaStorageService] Fetching user private record: \(recordName)")
        let recordID = CKRecord.ID(recordName: recordName)
        cloudKitService.privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                print("❌ [MediaStorageService] User private fetch error: \(error)")
                completion(.failure(error))
            } else if let record = record, let imageData = record["imageData"] as? Data {
                if let image = UIImage(data: imageData) {
                    print("✅ [MediaStorageService] Successfully loaded user private image: \(recordName)")
                    completion(.success(image))
                } else {
                    print("❌ [MediaStorageService] Failed to convert image data for user private: \(recordName)")
                    completion(.failure(MediaStorageError.imageConversionFailed))
                }
            } else {
                print("❌ [MediaStorageService] No record or image data found for user private: \(recordName)")
                completion(.failure(MediaStorageError.downloadFailed))
            }
        }
    }
    
    private func downloadFromAppPublicStorage(url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        // Extract record name from URL
        let components = url.components(separatedBy: "/")
        guard let recordName = components.last else {
            print("❌ [MediaStorageService] Invalid URL format for app public: \(url)")
            completion(.failure(MediaStorageError.invalidUrl))
            return
        }
        
        print("🔄 [MediaStorageService] Fetching app public record: \(recordName)")
        let recordID = CKRecord.ID(recordName: recordName)
        cloudKitService.publicDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                print("❌ [MediaStorageService] App public fetch error: \(error)")
                completion(.failure(error))
            } else if let record = record, let imageData = record["imageData"] as? Data {
                if let image = UIImage(data: imageData) {
                    print("✅ [MediaStorageService] Successfully loaded app public image: \(recordName)")
                    completion(.success(image))
                } else {
                    print("❌ [MediaStorageService] Failed to convert image data for app public: \(recordName)")
                    completion(.failure(MediaStorageError.imageConversionFailed))
                }
            } else {
                print("❌ [MediaStorageService] No record or image data found for app public: \(recordName)")
                completion(.failure(MediaStorageError.downloadFailed))
            }
        }
    }
    
    // MARK: - Delete Methods
    
    func deleteUserMedia(url: String, completion: @escaping (Error?) -> Void) {
        let components = url.components(separatedBy: "/")
        guard let recordName = components.last else {
            completion(MediaStorageError.invalidUrl)
            return
        }
        
        let recordID = CKRecord.ID(recordName: recordName)
        cloudKitService.privateDatabase.delete(withRecordID: recordID) { _, error in
            completion(error)
        }
    }
    
    func deleteFreeContentMedia(url: String, completion: @escaping (Error?) -> Void) {
        let components = url.components(separatedBy: "/")
        guard let recordName = components.last else {
            completion(MediaStorageError.invalidUrl)
            return
        }
        
        let recordID = CKRecord.ID(recordName: recordName)
        cloudKitService.publicDatabase.delete(withRecordID: recordID) { _, error in
            completion(error)
        }
    }
    
    func deleteSubscriptionContentMedia(url: String, completion: @escaping (Error?) -> Void) {
        let components = url.components(separatedBy: "/")
        guard let recordName = components.last else {
            completion(MediaStorageError.invalidUrl)
            return
        }
        
        let recordID = CKRecord.ID(recordName: recordName)
        cloudKitService.publicDatabase.delete(withRecordID: recordID) { _, error in
            completion(error)
        }
    }
}

// MARK: - Errors

enum MediaStorageError: Error, LocalizedError {
    case imageConversionFailed
    case uploadFailed
    case downloadFailed
    case invalidUrl
    case storageLocationNotSupported
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image data"
        case .uploadFailed:
            return "Failed to upload media"
        case .downloadFailed:
            return "Failed to download media"
        case .invalidUrl:
            return "Invalid media URL"
        case .storageLocationNotSupported:
            return "Storage location not supported"
        }
    }
} 