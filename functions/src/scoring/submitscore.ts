import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

export const submitScore = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const {matchId, myScore, opponentScore} = request.data as {
    matchId: string;
    myScore: number;
    opponentScore: number;
  };

  if (!matchId || myScore == null || opponentScore == null) {
    throw new HttpsError(
      "invalid-argument",
      "matchId, myScore, and opponentScore are required."
    );
  }

  const db = getFirestore();
  const matchRef = db.collection("matches").doc(matchId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(matchRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Match not found.");
    }
    const match = snap.data()!;

    if (match.status === "cancelled" || match.status === "confirmed") {
      throw new HttpsError(
        "failed-precondition",
        "This match is no longer active."
      );
    }

    if (uid !== match.sideAId && uid !== match.sideBId) {
      throw new HttpsError("permission-denied", "You're not part of this match.");
    }

    const side = uid === match.sideAId ? "A" : "B";
    const scoreA = side === "A" ? myScore : opponentScore;
    const scoreB = side === "A" ? opponentScore : myScore;

    tx.update(matchRef, {
      [`scoreSubmissions.${side}`]: {
        scoreA,
        scoreB,
        submittedAt: FieldValue.serverTimestamp(),
      },
      status: "awaiting_confirmation",
    });
  });

  return {ok: true};
});