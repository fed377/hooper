import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

interface ProposeMatchRequest {
  targetId: string;
  courtId: string;
  scheduledTime: string;
}

export const proposeMatch = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const {targetId, courtId, scheduledTime} = request.data as ProposeMatchRequest;
  if (!targetId || !courtId || !scheduledTime) {
    throw new HttpsError(
      "invalid-argument",
      "targetId, courtId, and scheduledTime are required."
    );
  }
  if (targetId === uid) {
    throw new HttpsError("invalid-argument", "Cannot challenge yourself.");
  }

  const db = getFirestore();
  const sourceRef = db.collection("playerProfiles").doc(uid);
  const targetRef = db.collection("playerProfiles").doc(targetId);
  const matchRequestRef = db.collection("matchRequests").doc();

  // A transaction matters here: the client's feed may be showing a
  // stale "unlocked" state if someone else challenged this target a
  // moment ago. Re-check isLocked inside the transaction, not just
  // in the read that populated the feed.
  await db.runTransaction(async (taction) => {
    const [sourceSnap, targetSnap] = await Promise.all([
      taction.get(sourceRef),
      taction.get(targetRef),
    ]);

    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "That player no longer exists.");
    }
    if (sourceSnap.data()?.isLocked) {
      throw new HttpsError(
        "failed-precondition",
        "You're already in an active match."
      );
    }
    if (targetSnap.data()?.isLocked) {
      throw new HttpsError(
        "failed-precondition",
        "That player just got locked into another match."
      );
    }

    taction.set(matchRequestRef, {
      mode: "1v1",
      initiatorId: uid,
      targetId,
      courtId,
      scheduledTime,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  // Note: this only creates the *request* — locking both profiles
  // happens in acceptRequest.ts once the target accepts, per the
  // matchmaking flow from the spec. Don't lock on propose.
  return {matchRequestId: matchRequestRef.id};
});