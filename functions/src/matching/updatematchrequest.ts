import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { postSystemMessage } from "./chatutils";

interface UpdateMatchRequestPayload {
  matchRequestId: string;
  court?: string;
  scheduledTime?: string; // ISO 8601
}

export const updateMatchRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const { matchRequestId, court, scheduledTime } =
    request.data as UpdateMatchRequestPayload;
  if (!matchRequestId || (!court?.trim() && !scheduledTime)) {
    throw new HttpsError(
      "invalid-argument",
      "matchRequestId and at least one of court/scheduledTime are required.",
    );
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
        "This request is no longer open for changes.",
      );
    }
    if (uid !== req.initiatorId && uid !== req.targetId) {
      throw new HttpsError(
        "permission-denied",
        "You're not part of this request.",
      );
    }

    const changes: Record<string, unknown> = {};
    const changeDescriptions: string[] = [];

    if (court?.trim() && court.trim() !== req.courtText) {
      changes.court = court.trim();
      changeDescriptions.push(`the court to ${court.trim()}`);
    }
    if (scheduledTime) {
      const newTimestamp = Timestamp.fromDate(new Date(scheduledTime));
      if (isNaN(newTimestamp.toDate().getTime())) {
        throw new HttpsError(
          "invalid-argument",
          "scheduledTime is not a valid date.",
        );
      }
      if (
        newTimestamp.toMillis() !== (req.scheduledTime as Timestamp).toMillis()
      ) {
        changes.scheduledTime = newTimestamp;
        changeDescriptions.push(
          `the time to ${newTimestamp.toDate().toLocaleString()}`,
        );
      }
    }

    if (Object.keys(changes).length === 0) return;

    tx.update(requestRef, changes);

    const changeText = `Changed ${changeDescriptions.join(" and ")}`;
    const chatRef = db.collection("chats").doc(req.chatId);
    postSystemMessage(tx, chatRef, changeText, {
      matchRequestId,
      senderId: uid,
    });
  });

  return { ok: true };
});
