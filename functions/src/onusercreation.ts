import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as functions from "firebase-functions";

export const onUserCreation = functions.identity.beforeUserCreated(
  async (event) => {
    const db = getFirestore();
    const batch = db.batch();
    const user = event.data;

    if (!user) return;

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
      displayName: user.displayName ?? "New Player",
      photoUrl: user.photoURL ?? null,
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
      status: "active",
    });

    await batch.commit();
  },
);
