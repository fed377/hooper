import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

export const cancelMatch = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const {matchId} = request.data as {matchId: string};
  if (!matchId) {
    throw new HttpsError("invalid-argument", "matchId is required.");
  }

  const db = getFirestore();
  const matchRef = db.collection("matches").doc(matchId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(matchRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "That match no longer exists.");
    }
    const match = snap.data()!;

    if (uid !== match.sideAId && uid !== match.sideBId) {
      throw new HttpsError("permission-denied", "You're not part of this match.");
    }
    
    if (match.status !== "scheduled" && match.status !== "in_progress") {
      throw new HttpsError(
        "failed-precondition",
        "This match can no longer be freely cancelled."
      );
    }

    const sideARef = db.collection("playerProfiles").doc(match.sideAId);
    const sideBRef = db.collection("playerProfiles").doc(match.sideBId);

    tx.update(matchRef, {status: "cancelled"});
    tx.update(sideARef, {lockedMatchIds: FieldValue.arrayRemove(matchId)});
    tx.update(sideBRef, {lockedMatchIds: FieldValue.arrayRemove(matchId)});
  });

  return {ok: true};
});