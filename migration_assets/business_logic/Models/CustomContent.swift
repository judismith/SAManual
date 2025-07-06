import Foundation

struct CustomContent: Identifiable, Codable {
    let id: String
    let uid: String
    let title: String
    let content: String
    let mediaUrls: [String] // User-uploaded media stored in user's private iCloud
    let tags: [String]
    let dataStore: DataStore // Custom content is user-generated and stored in iCloud
    let accessLevel: DataAccessLevel // Custom content is private to user
    let mediaStorageLocation: MediaStorageLocation // Custom content media is always user private
    
    init(id: String, uid: String, title: String, content: String, mediaUrls: [String], tags: [String]) {
        self.id = id
        self.uid = uid
        self.title = title
        self.content = content
        self.mediaUrls = mediaUrls
        self.tags = tags
        self.dataStore = .iCloud
        self.accessLevel = .userPrivate
        self.mediaStorageLocation = .userPrivate
    }
} 