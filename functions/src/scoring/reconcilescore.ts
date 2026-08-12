import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { calculateElo } from "./calculateelo";

export const reconcileScore = onDocumentUpdated(
  "matches/{matchId}",
  async (event) => {
    const after = event.data?.after.data();
    if (!after) return;

    if (after.status === "confirmed" || after.status === "cancelled") return;

    const submission = after.scoreSubmissions;
    if (!submission?.A || !submission?.B) return;

    const db = getFirestore();
    const matchRef = db.collection("matches").doc(event.params.matchId);

    const agree =
      submission.A.scoreA === submission.B.scoreA &&
      submission.A.scoreB === submission.B.scoreB;

    if (!agree) {
      if (after.status !== "disputed") {
        await matchRef.update({ status: "disputed" });
      }
      return;
    }

    const scoreA = submission.A.scoreA;
    const scoreB = submission.A.scoreB;
    const aWon = scoreA > scoreB;
    const pointDiff = Math.abs(scoreA - scoreB);

    await db.runTransaction(async (tx) => {
      const freshSnap = await tx.get(matchRef);
      if (freshSnap.data()?.status === "confirmed") return;

      const sideARef = db.collection("playerProfiles").doc(after.sideAId);
      const sideBRef = db.collection("playerProfiles").doc(after.sideBId);
      const [aSnap, bSnap] = await Promise.all([
        tx.get(sideARef),
        tx.get(sideBRef),
      ]);
      const aData = aSnap.data()!;
      const bData = bSnap.data()!;

      const aRecentForm: boolean[] = aData.recentForm ?? [];
      const bRecentForm: boolean[] = bData.recentForm ?? [];
      const aFormUpdated = [aWon, ...aRecentForm].slice(0, 5);
      const bFormUpdated = [!aWon, ...bRecentForm].slice(0, 5);

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
        recentForm: aFormUpdated,
        lockedMatchId: null,
      });
      tx.update(sideBRef, {
        elo: bResult.newRating,
        gamesPlayed1v1: FieldValue.increment(1),
        isLocked: false,
        recentForm: bFormUpdated,
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
  },
);
