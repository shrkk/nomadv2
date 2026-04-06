"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserDeleted = void 0;
const v1_1 = require("firebase-functions/v1");
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
(0, app_1.initializeApp)();
/**
 * Triggered when a Firebase Auth user is deleted (via Console, Admin SDK, or in-app).
 * Cleans up:
 *   - users/{uid}          — user profile document
 *   - usernames/{handle}   — username reservation (read from user doc before deleting)
 */
exports.onUserDeleted = v1_1.auth.user().onDelete(async (user) => {
    var _a;
    const db = (0, firestore_1.getFirestore)();
    const userRef = db.collection("users").doc(user.uid);
    const userSnap = await userRef.get();
    const handle = (_a = userSnap.data()) === null || _a === void 0 ? void 0 : _a.handle;
    const batch = db.batch();
    batch.delete(userRef);
    if (handle) {
        batch.delete(db.collection("usernames").doc(handle.toLowerCase()));
    }
    await batch.commit();
    console.log(`Cleaned up user ${user.uid} (handle: ${handle !== null && handle !== void 0 ? handle : "none"})`);
});
//# sourceMappingURL=index.js.map