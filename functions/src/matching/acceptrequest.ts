import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

export const acceptRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const {matchRequestId} = request.data as {matchRequestId: string};
  if (!matchRequestId) {
    throw new HttpsError("invalid-argument", "matchRequestId is required.");
  }

  const db = getFirestore();
  const requestRef = db.collection("matchRequests").doc(matchRequestId);
  const matchRef = db.collection("matches").doc();

  await db.runTransaction(async (taction) => {
    const reqSnap = await taction.get(requestRef);
    if (!reqSnap.exists) {
      throw new HttpsError("not-found", "That request no longer exists.");
    }
    const req = reqSnap.data()!;

    if (req.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `This request is already ${req.status}.`
      );
    }
    // Only the person who was challenged can accept it — the
    // initiator confirming their own request would bypass consent.
    if (uid !== req.targetId) {
      throw new HttpsError(
        "permission-denied",
        "Only the challenged player can accept this."
      );
    }

    const sourceRef = db.collection("playerProfiles").doc(req.initiatorId);
    const targetRef = db.collection("playerProfiles").doc(req.targetId);
    const [initiatorSnap, targetSnap] = await Promise.all([
      taction.get(sourceRef),
      taction.get(targetRef),
    ]);

    // Re-check lock state at accept time too: time may have passed
    // since the request was created, and the initiator could have
    // gotten locked into a different match in the meantime.
    if (initiatorSnap.data()?.isLocked) {
      throw new HttpsError(
        "failed-precondition",
        "The challenger is no longer available."
      );
    }
    if (targetSnap.data()?.isLocked) {
      throw new HttpsError(
        "failed-precondition",
        "You're already locked into another match."
      );
    }

    taction.set(matchRef, {
      mode: req.mode,
      sideAId: req.initiatorId,
      sideBId: req.targetId,
      courtId: req.courtId,
      scheduledTime: req.scheduledTime,
      status: "scheduled",
      scoreSubmissions: {},
      createdAt: FieldValue.serverTimestamp(),
    });

    taction.update(requestRef, {status: "accepted", matchId: matchRef.id});

    taction.update(sourceRef, {isLocked: true, lockedMatchId: matchRef.id});
    taction.update(targetRef, {isLocked: true, lockedMatchId: matchRef.id});
  });

  return {matchId: matchRef.id};
});