import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

export const declineRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const {matchId} = request.data as {matchId: string};
  if(!matchId){
    throw new HttpsError("invalid-argument", "matchId is required");
  }

  const db = getFirestore();
  const matchRef = db.collection("matches").doc(matchId);

  await db.runTransaction(async (taction)=>{
    const snap = await taction.get(matchRef);
    if(!snap.exists){
        throw new HttpsError("not-found", "That match no longer exists. ");
    }
    const match = snap.data()!;

    if(uid !== match.sideAId && uid !== match.sideBId){
        throw new HttpsError("permission-denied", "You're not part of this match. ");
    }

    if(match.status !== "scheduled"){
        throw new HttpsError(
            "failed-precondition",
             `Match is already ${match.status} and cannot be cancelled. `
            );
    }

    const sideARef = db.collection("playerProfiles").doc(match.sideAId);
    const sideBRef = db.collection("playerProfiles").doc(match.sideBId);

    taction.update(matchRef, {status: "cancelled"});
    taction.update(sideARef, {isLocked: false, lockedMatchId: null});
    taction.update(sideBRef, {isLocked: false, lockedMatchId: null});

  })

  return {ok: true};
})