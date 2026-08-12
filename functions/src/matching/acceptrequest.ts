import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { postSystemMessage } from "./chatutils";

export const acceptRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const { matchRequestId } = request.data as { matchRequestId: string };
  if (!matchRequestId) {
    throw new HttpsError("invalid-argument", "matchRequestId is required.");
  }

  const db = getFirestore();
  const requestRef = db.collection("matchRequests").doc(matchRequestId);
  const matchRef = db.collection("matches").doc();

  await db.runTransaction(async (tx) => {
    const reqSnap = await tx.get(requestRef);
    if (!reqSnap.exists) {
      throw new HttpsError("not-found", "That request no longer exists.");
    }
    const req = reqSnap.data()!;

    if (req.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `This request is already ${req.status}.`,
      );
    }
    
    if (uid !== req.targetId) {
      throw new HttpsError(
        "permission-denied",
        "Only the challenged player can accept this.",
      );
    }

    const sourceRef = db.collection("playerProfiles").doc(req.initiatorId);
    const targetRef = db.collection("playerProfiles").doc(req.targetId);
    const [initiatorSnap, targetSnap] = await Promise.all([
      tx.get(sourceRef),
      tx.get(targetRef),
    ]);

    if (initiatorSnap.data()?.isLocked) {
      throw new HttpsError(
        "failed-precondition",
        "The challenger is no longer available.",
      );
    }
    if (targetSnap.data()?.isLocked) {
      throw new HttpsError(
        "failed-precondition",
        "You're already locked into another match.",
      );
    }

    tx.set(matchRef, {
      mode: req.mode,
      sideAId: req.initiatorId,
      sideBId: req.targetId,
      court: req.court,
      scheduledTime: req.scheduledTime,
      status: "scheduled",
      scoreSubmissions: {},
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.update(requestRef, { status: "accepted", matchId: matchRef.id });

    tx.update(sourceRef, { isLocked: true, lockedMatchId: matchRef.id });
    tx.update(targetRef, { isLocked: true, lockedMatchId: matchRef.id });

    const chatRef = db.collection("chats").doc(req.chatId);
    postSystemMessage(
      tx,
      chatRef,
      "Match confirmed! You're both locked in.",
      {matchRequestId: matchRequestId}
    );
  });

  return { matchId: matchRef.id };
});
