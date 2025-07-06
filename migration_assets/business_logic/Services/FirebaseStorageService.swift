import Foundation
import FirebaseStorage

class FirebaseStorageService {
    static let shared = FirebaseStorageService()
    private let storage = Storage.storage()
    
    // Upload profile photo
    func uploadProfilePhoto(uid: String, imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        let ref = storage.reference().child("profile_photos/\(uid).jpg")
        ref.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
            } else {
                ref.downloadURL { url, error in
                    if let url = url {
                        completion(.success(url.absoluteString))
                    } else if let error = error {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    // Upload journal media
    func uploadJournalMedia(uid: String, journalId: String, fileName: String, data: Data, completion: @escaping (Result<String, Error>) -> Void) {
        let ref = storage.reference().child("journal_media/\(uid)/\(journalId)/\(fileName)")
        ref.putData(data, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
            } else {
                ref.downloadURL { url, error in
                    if let url = url {
                        completion(.success(url.absoluteString))
                    } else if let error = error {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    // Download file
    func downloadFile(from url: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let ref = storage.reference(forURL: url)
        ref.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let data = data {
                completion(.success(data))
            } else if let error = error {
                completion(.failure(error))
            }
        }
    }
} 