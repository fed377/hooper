import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

const REQUEST_EXPIRY_HOURS = 24;
const EXPIRY_TEXT = "This request expired after 24 hours with no response.";

export const expireStaleRequests = onSchedule("every 30 minutes", async () => {
  const db = getFirestore();
  const cutoff = Timestamp.fromMillis(
    Date.now() - REQUEST_EXPIRY_HOURS * 60 * 60 * 1000,
  );

  const staleSnap = await db
    .collection("matchRequests")
    .where("status", "==", "pending")
    .where("createdAt", "<=", cutoff)
    .get();

  if (staleSnap.empty) return;

  const batch = db.batch();
  staleSnap.docs.forEach((doc) => {
    batch.update(doc.ref, { status: "expired" });

    const chatId = doc.data().chatId as string | undefined;
    if (chatId) {
      const chatRef = db.collection("chats").doc(chatId);
      batch.set(chatRef.collection("messages").doc(), {
        isSystem: true,
        text: EXPIRY_TEXT,
        matchRequestId: doc.id,
        senderId: null,
        createdAt: FieldValue.serverTimestamp(),
      });
      batch.update(chatRef, {
        lastMessageAt: FieldValue.serverTimestamp(),
        lastMessagePreview: EXPIRY_TEXT,
      });
    }
  });
  await batch.commit();
});
