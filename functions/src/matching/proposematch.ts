import {
  FieldValue,
  GeoPoint,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ensureChatExists, pairChatId, postSystemMessage } from "./chatutils";

interface ProposeMatchRequest {
  targetId: string;
  court: string;
  scheduledTime: string; // ISO 8601
  latitude: number;
  longitude: number;
  priv: boolean;
  friendly: boolean;
}

export const proposeMatch = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const { targetId, court, scheduledTime, latitude, longitude, priv, friendly } =
    request.data as ProposeMatchRequest;

  if (!targetId || !court.trim() || !scheduledTime || !latitude || !longitude) {
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
  const requesterRef = db.collection("playerProfiles").doc(uid);
  const targetRef = db.collection("playerProfiles").doc(targetIdTrim);
  const matchRequestRef = db.collection("matchRequests").doc();
  const chatId = pairChatId(uid, targetId);
  const chatRef = db.collection("chats").doc(chatId);
  const proposalText = `Proposed ${court.trim()} at $$${scheduledTimestamp.toMillis()}$$`;

  await db.runTransaction(async (tx) => {
    const [requesterSnap, targetSnap, chatSnap] = await Promise.all([
      tx.get(requesterRef),
      tx.get(targetRef),
      tx.get(chatRef),
    ]);

    // A suspended/banned caller shouldn't be able to keep sending new
    // challenges just because setUserStatus only cleaned up what existed
    // at ban time — this closes that gap.
    const requesterStatus = requesterSnap.data()?.accountStatus;
    if (requesterStatus && requesterStatus !== "active") {
      throw new HttpsError(
        "permission-denied",
        "Your account can't send match requests right now.",
      );
    }

    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "That player no longer exists.");
    }
    // nearbyMatchups already excludes restricted accounts from
    // discovery, so this shouldn't normally be reachable — but a
    // stale client screen or a direct call could still try. targetSnap
    // is already being read above for the exists check, so this is a
    // free check, not an extra round trip.
    if (targetSnap.data()?.accountStatus && targetSnap.data()?.accountStatus !== "active") {
      // "not-found" deliberately, not a distinguishable "this account
      // is restricted" error — same message as if the player didn't
      // exist, so a challenger can't use this to figure out someone
      // specific just got banned.
      throw new HttpsError("not-found", "That player is no longer available.");
    }
    // No isLocked check anymore: a player with matches already
    // scheduled — even one happening literally right now — can still
    // be challenged. They just won't see the new request until
    // LockGate releases them (see the Flutter side).

    // If this chat already has an unresolved request, don't let a
    // second one pile on top of it — all reads must happen before any
    // writes in a transaction, so this check has to come before
    // ensureChatExists below writes anything.
    const priorRequestId = chatSnap.data()?.lastMatchRequestId as string | undefined;
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
      location: new GeoPoint(latitude, longitude),
      priv: priv,
      friendly: friendly,
    });

    tx.update(chatRef, { lastMatchRequestId: matchRequestRef.id });

    postSystemMessage(tx, chatRef, proposalText, {
      matchRequestId: matchRequestRef.id,
    });
  });

  return { matchRequestId: matchRequestRef.id, chatId: chatRef.id };
});
