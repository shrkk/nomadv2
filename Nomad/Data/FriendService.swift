@preconcurrency import FirebaseFirestore
import FirebaseAuth

struct FoundUser {
    let uid: String
    let handle: String
    let avatarHue: Double
}

actor FriendService {
    static let shared = FriendService()
    private init() {}

    func searchUser(handle: String) async throws -> FoundUser? {
        let doc = try await FirestoreSchema.usernameDoc(handle).getDocument()
        guard doc.exists, let uid = doc.data()?["uid"] as? String else { return nil }
        return FoundUser(uid: uid, handle: handle, avatarHue: avatarHue(for: uid))
    }

    func addFriend(friend: FoundUser) async throws {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            FirestoreSchema.FriendFields.handle: friend.handle,
            FirestoreSchema.FriendFields.avatarHue: friend.avatarHue,
            FirestoreSchema.FriendFields.addedAt: Timestamp()
        ]
        try await FirestoreSchema.friendDoc(myUid, friendUid: friend.uid).setData(data)
    }

    func isFriend(uid: String) async throws -> Bool {
        guard let myUid = Auth.auth().currentUser?.uid else { return false }
        let doc = try await FirestoreSchema.friendDoc(myUid, friendUid: uid).getDocument()
        return doc.exists
    }

    private func avatarHue(for uid: String) -> Double {
        Double(abs(uid.hashValue) % 360)
    }
}
