import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as functionsV1 from "firebase-functions/v1";

// This is a v1-style trigger (auth triggers aren't available in the v2
// SDK yet) — v1 and v2 functions coexist fine in the same codebase,
// this is just the one place that still uses the older import.
export const onUserCreate = functionsV1
  .region("europe-west1")
  .auth.user()
  .onCreate(async (user) => {
    const db = getFirestore();
    const batch = db.batch();

    batch.set(db.collection("users").doc(user.uid), {
      authProviderId: user.uid,
      phoneOrEmail: user.email ?? null,
      displayName: user.displayName ?? "New Player",
      createdAt: FieldValue.serverTimestamp(),
      status: "active",
    });

    batch.set(db.collection("playerProfiles").doc(user.uid), {
      photoUrl: user.photoURL,
      elo: 1200,
      gamesPlayed1v1: 0,
      isLocked: false,
      lockedMatchId: null,
      visibilityRadiusKm: 10,
      lastActive: FieldValue.serverTimestamp(),
      displayName: user.displayName ?? "New Player",
      recentForm: [0, 0, 0, 0, 0],
    });


    batch.set(db.collection("playerProfiles").doc(user.uid),{
      displayName: user.displayName ?? "New Player",
      photoUrl: user.photoURL,
      elo: 1200, 
      visibilityRadius: 10,
      isLocked: false,
      lockedMatchId: null,
      lastActive: FieldValue.serverTimestamp(),
      recentForm: [],
      gamesPlayed1v1: 0,
    })

    await batch.commit();
  });
