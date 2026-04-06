import { auth } from "firebase-functions/v1";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();

/**
 * Triggered when a Firebase Auth user is deleted (via Console, Admin SDK, or in-app).
 * Cleans up:
 *   - users/{uid}          — user profile document
 *   - usernames/{handle}   — username reservation (read from user doc before deleting)
 */
export const onUserDeleted = auth.user().onDelete(async (user) => {
  const db = getFirestore();
  const userRef = db.collection("users").doc(user.uid);

  const userSnap = await userRef.get();
  const handle = userSnap.data()?.handle as string | undefined;

  const batch = db.batch();
  batch.delete(userRef);
  if (handle) {
    batch.delete(db.collection("usernames").doc(handle.toLowerCase()));
  }
  await batch.commit();

  console.log(`Cleaned up user ${user.uid} (handle: ${handle ?? "none"})`);
});
