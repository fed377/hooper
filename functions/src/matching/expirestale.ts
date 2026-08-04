import {onSchedule} from "firebase-functions/v2/scheduler";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

const REQUEST_EXPIRY_HOURS = 24;

export const expireStaleRequests = onSchedule("every 30 minutes", async () => {
  const db = getFirestore();
  const cutoff = Timestamp.fromMillis(
    Date.now() - REQUEST_EXPIRY_HOURS * 60 * 60 * 1000
  );

  const staleSnap = await db
    .collection("matchRequests")
    .where("status", "==", "pending")
    .where("createdAt", "<=", cutoff)
    .get();

  if (staleSnap.empty) return;

  const batch = db.batch();
  staleSnap.docs.forEach((doc) => batch.update(doc.ref, {status: "expired"}));
  await batch.commit();
});