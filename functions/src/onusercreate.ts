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
      createdAt: FieldValue.serverTimestamp(),
      status: "active",
    });

    batch.set(db.collection("preferences").doc(user.uid), {
      blockedUsers: [],
      blockedBy: [],
    });

    batch.set(db.collection("playerProfiles").doc(user.uid), {
      displayName: "New Player",
      photoUrl: user.photoURL,
      bannerUrl: null,
      elo: 1200,
      visibilityRadius: 10,
      lockedMatchIds: [],
      completedMatches: [],
      lastActive: FieldValue.serverTimestamp(),
      recentForm: [],
      fcmTokens: [],
      gamesPlayed1v1: 0,
      bio: "",
      height: 0,
      position: 1,
      status: "normal",
      blockedBy: [],
      blockedUsers: [],
    });

    await batch.commit();
  });
