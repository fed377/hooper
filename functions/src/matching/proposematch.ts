import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ensureChatExists, pairChatId, postSystemMessage } from "./chatutils";

interface ProposeMatchRequest {
  targetId: string;
  court: string;
  scheduledTime: string; // ISO 8601
}

export const proposeMatch = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const { targetId, court, scheduledTime } =
    request.data as ProposeMatchRequest;

  if (!targetId || !court.trim() || !scheduledTime) {
    throw new HttpsError(
      "invalid-argument",
      "targetId, court, and scheduledTime are required.",
    );
  }

  const targetIdTrim = targetId.trim();

  if (targetIdTrim === uid) {
    throw new HttpsError("invalid-argument", "Cannot challenge yourself.");
  }

  const scheduledTimestamp = Timestamp.fromDate(new Date(scheduledTime));
  if (isNaN(scheduledTimestamp.toDate().getTime())) {
    throw new HttpsError(
      "invalid-argument",
      "scheduledTime is not a valid date.",
    );
  }

  const db = getFirestore();
  //const requesterRef = db.collection("playerProfiles").doc(uid);
  const targetRef = db.collection("playerProfiles").doc(targetIdTrim);
  const matchRequestRef = db.collection("matchRequests").doc();
  const chatId = pairChatId(uid, targetId);
  const chatRef = db.collection("chats").doc(chatId);
  const proposalText = `Proposed ${court.trim()} at ${scheduledTimestamp.toDate().toLocaleString()}`;

  await db.runTransaction(async (tx) => {
    const [targetSnap, chatSnap] = await Promise.all([
      tx.get(targetRef),
      tx.get(chatRef),
    ]);

    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "That player no longer exists.");
    }

    const priorRequestId = chatSnap.data()?.lastMatchRequestId as
      | string
      | undefined;

    if (priorRequestId) {
      const priorSnap = await tx.get(
        db.collection("matchRequests").doc(priorRequestId),
      );
      if (priorSnap.data()?.status === "pending") {
        throw new HttpsError(
          "failed-precondition",
          "There's already an open request in your conversation with this player.",
        );
      }
    }

    await ensureChatExists(tx, chatRef, uid, targetId, chatSnap);

    tx.set(matchRequestRef, {
      mode: "1v1",
      initiatorId: uid,
      targetId: targetIdTrim,
      court: court.trim(),
      scheduledTime: scheduledTimestamp,
      status: "pending",
      chatId: chatId,
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.update(chatRef, { lastMatchRequestId: matchRequestRef.id });

    postSystemMessage(tx, chatRef, proposalText, {
      matchRequestId: matchRequestRef.id,
    });
  });

  return { matchRequestId: matchRequestRef.id, chatId: chatRef.id };
});
