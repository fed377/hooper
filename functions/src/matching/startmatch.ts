import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/**
 * Called by LockGate (Flutter side) when it notices a match in the
 * current user's lockedMatchIds has a scheduledTime that's already
 * passed. This replaces the old server-cron approach (a scheduled
 * function polling every few minutes) — detection is now driven by
 * whichever player happens to have the app open, not a background
 * job. Trade-off: if neither player opens the app around game time,
 * nothing flips this until one of them eventually does, however much
 * later that is. Deliberately re-validates scheduledTime server-side
 * rather than trusting the client's "it's time" judgment — a client
 * could otherwise call this early to force an opponent into the
 * score-entry gate prematurely.
 */
export const startMatch = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const { matchId } = request.data as { matchId: string };
  if (!matchId) {
    throw new HttpsError("invalid-argument", "matchId is required.");
  }

  const db = getFirestore();
  const matchRef = db.collection("matches").doc(matchId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(matchRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "That match no longer exists.");
    }
    const match = snap.data()!;

    if (uid !== match.sideAId && uid !== match.sideBId) {
      throw new HttpsError(
        "permission-denied",
        "You're not part of this match.",
      );
    }

    if (match.status !== "scheduled" && match.status !== "in_progress") return;

    const scheduledTime = match.scheduledTime as Timestamp;
    if (scheduledTime.toMillis() > Date.now()) {
      throw new HttpsError(
        "failed-precondition",
        "This match hasn't reached its scheduled time yet.",
      );
    }

    tx.update(matchRef, {
      status: "in_progress",
      appearedIds: FieldValue.arrayUnion(uid),
    });
  });

  return { ok: true };
});
