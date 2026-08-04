import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {calculateElo} from "../calculateelo";

export const reconcileScore = onDocumentUpdated("matches/{matchId}", async (event) => {
  const after = event.data?.after.data();
  if (!after) return;

  // Nothing to do once a match is already resolved either way.
  if (after.status === "confirmed" || after.status === "cancelled") return;

  const subs = after.scoreSubmissions;
  if (!subs?.A || !subs?.B) return; // still waiting on one side

  const db = getFirestore();
  const matchRef = db.collection("matches").doc(event.params.matchId);

  const agree = subs.A.scoreA === subs.B.scoreA && subs.A.scoreB === subs.B.scoreB;

  if (!agree) {
    if (after.status !== "disputed") {
      await matchRef.update({status: "disputed"});
    }
    return;
  }

  const scoreA = subs.A.scoreA;
  const scoreB = subs.A.scoreB;
  const aWon = scoreA > scoreB;
  const pointDiff = Math.abs(scoreA - scoreB);

  await db.runTransaction(async (tx) => {
    const freshSnap = await tx.get(matchRef);
    if (freshSnap.data()?.status === "confirmed") return;

    const sideARef = db.collection("playerProfiles").doc(after.sideAId);
    const sideBRef = db.collection("playerProfiles").doc(after.sideBId);
    const [aSnap, bSnap] = await Promise.all([tx.get(sideARef), tx.get(sideBRef)]);
    const aData = aSnap.data()!;
    const bData = bSnap.data()!;

    const aResult = calculateElo({
      rating: aData.elo,
      opponentRating: bData.elo,
      result: aWon ? 1 : 0,
      gamesPlayed: aData.gamesPlayed1v1 ?? 0,
      pointDiff,
    });
    const bResult = calculateElo({
      rating: bData.elo,
      opponentRating: aData.elo,
      result: aWon ? 0 : 1,
      gamesPlayed: bData.gamesPlayed1v1 ?? 0,
      pointDiff,
    });

    tx.update(matchRef, {
      status: "confirmed",
      scoreA,
      scoreB,
      confirmedAt: FieldValue.serverTimestamp(),
      eloDeltaA: aResult.delta,
      eloDeltaB: bResult.delta,
    });

    tx.update(sideARef, {
      elo: aResult.newRating,
      gamesPlayed1v1: FieldValue.increment(1),
      isLocked: false,
      lockedMatchId: null,
    });
    tx.update(sideBRef, {
      elo: bResult.newRating,
      gamesPlayed1v1: FieldValue.increment(1),
      isLocked: false,
      lockedMatchId: null,
    });

    tx.set(matchRef.collection("eloHistory").doc(), {
      playerId: after.sideAId,
      matchId: event.params.matchId,
      ratingBefore: aData.elo,
      ratingAfter: aResult.newRating,
      delta: aResult.delta,
      timestamp: FieldValue.serverTimestamp(),
    });
    tx.set(matchRef.collection("eloHistory").doc(), {
      playerId: after.sideBId,
      matchId: event.params.matchId,
      ratingBefore: bData.elo,
      ratingAfter: bResult.newRating,
      delta: bResult.delta,
      timestamp: FieldValue.serverTimestamp(),
    });
  });
});