import { FieldValue, Firestore, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { requireAdmin } from "./adminutils";
import { pairChatId } from "./matching/chatutils";

type UserStatus = "active" | "suspended" | "banned";
const UNRESOLVED_MATCH_STATUSES = [
  "scheduled",
  "in_progress",
  "awaiting_confirmation",
  "disputed",
];

export const setUserStatus = onCall(async (request) => {
  requireAdmin(request);

  const { targetUid, status, reason } = request.data as {
    targetUid: string;
    status: UserStatus;
    reason?: string;
  };
  if (!targetUid || !["active", "suspended", "banned"].includes(status)) {
    throw new HttpsError(
      "invalid-argument",
      "targetUid and a valid status ('active' | 'suspended' | 'banned') are required.",
    );
  }

  const db = getFirestore();

  const batch = db.batch();
  batch.update(db.collection("users").doc(targetUid), {
    status,
    statusReason: reason ?? null,
    statusUpdatedAt: FieldValue.serverTimestamp(),
  });
  batch.update(db.collection("playerProfiles").doc(targetUid), {
    accountStatus: status,
  });
  await batch.commit();

  if (status !== "active") {
    await cancelActiveMatchesFor(db, targetUid);
  }

  return { ok: true };
});

async function cancelActiveMatchesFor(
  db: Firestore,
  uid: string,
): Promise<void> {

  const [asA, asB] = await Promise.all([
    db
      .collection("matches")
      .where("sideAId", "==", uid)
      .where("status", "in", UNRESOLVED_MATCH_STATUSES)
      .get(),
    db
      .collection("matches")
      .where("sideBId", "==", uid)
      .where("status", "in", UNRESOLVED_MATCH_STATUSES)
      .get(),
  ]);
  const matchDocs = [...asA.docs, ...asB.docs];

  const [reqAsInitiator, reqAsTarget] = await Promise.all([
    db
      .collection("matchRequests")
      .where("initiatorId", "==", uid)
      .where("status", "==", "pending")
      .get(),
    db
      .collection("matchRequests")
      .where("targetId", "==", uid)
      .where("status", "==", "pending")
      .get(),
  ]);
  const requestDocs = [...reqAsInitiator.docs, ...reqAsTarget.docs];

  if (matchDocs.length === 0 && requestDocs.length === 0) return;

  const batch = db.batch();
  const CANCEL_TEXT =
    "This match was cancelled — one of the players is no longer available.";

  for (const doc of matchDocs) {
    const match = doc.data();
    batch.update(doc.ref, { status: "cancelled" });
    batch.update(db.collection("playerProfiles").doc(match.sideAId), {
      lockedMatchIds: FieldValue.arrayRemove(doc.id),
    });
    batch.update(db.collection("playerProfiles").doc(match.sideBId), {
      lockedMatchIds: FieldValue.arrayRemove(doc.id),
    });

    const chatRef = db
      .collection("chats")
      .doc(pairChatId(match.sideAId, match.sideBId));
    batch.set(chatRef.collection("messages").doc(), {
      isSystem: true,
      text: CANCEL_TEXT,
      matchRequestId: null,
      senderId: null,
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.update(chatRef, {
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessagePreview: CANCEL_TEXT,
    });
  }

  for (const doc of requestDocs) {
    batch.update(doc.ref, { status: "withdrawn" });
  }

  await batch.commit();
}
