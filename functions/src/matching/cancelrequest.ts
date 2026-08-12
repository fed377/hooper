import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { postSystemMessage } from "./chatutils";

export const cancelRequest = onCall(async (request) => {
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

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(requestRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "That request no longer exists.");
    }
    const req = snap.data()!;

    if (req.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `This request is already ${req.status}.`,
      );
    }
    // Distinct from declineRequest: only the person who SENT the
    // challenge can withdraw it this way. The target says no via
    // declineRequest instead — kept as separate statuses
    // ("withdrawn" vs "declined") so the history reads correctly.
    if (uid !== req.initiatorId) {
      throw new HttpsError(
        "permission-denied",
        "Only the player who sent this challenge can cancel it.",
      );
    }

    tx.update(requestRef, { status: "withdrawn" });

    const chatRef = db.collection("chats").doc(req.chatId);
    postSystemMessage(tx, chatRef, "The challenger cancelled this request.", {
      matchRequestId,
    });
  });

  return { ok: true };
});
