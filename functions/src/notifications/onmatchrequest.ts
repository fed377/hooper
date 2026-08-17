// functions/src/notifications/onMatchRequestCreated.ts
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

export const onMatchRequestCreated = onDocumentCreated(
  "matchRequests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request) return;

    const db = getFirestore();
    const [initiatorSnap, targetSnap] = await Promise.all([
      db.collection("playerProfiles").doc(request.initiatorId).get(),
      db.collection("playerProfiles").doc(request.targetId).get(),
    ]);
    const tokens = (targetSnap.data()?.fcmTokens as string[]) ?? [];
    if (tokens.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "New challenge",
        body: `${initiatorSnap.data()?.displayName ?? "Someone"} challenged you to a 1v1`,
        imageUrl: targetSnap.data()?.photoUrl,
      },
      data: {
        type: "match_request",
        chatId: request.chatId,
      },
    });
    const deadTokens = response.responses
      .map((r, i) =>
        r.error?.code === "messaging/registration-token-not-registered"
          ? tokens[i]
          : null,
      )
      .filter((t): t is string => t !== null);
    if (deadTokens.length > 0) {
      await targetSnap.ref.update({
        fcmTokens: FieldValue.arrayRemove(...deadTokens),
      });
    }
  },
);
