import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/firestore";

// functions/src/notifications/onChatMessageCreated.ts
export const onChatMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message || message.isSystem) return;

    const chatId = event.params.chatId;
    const db = getFirestore();
    const chatSnap = await db.collection("chats").doc(chatId).get();
    const participantIds = chatSnap.data()?.participantIds as string[];
    const recipientId = participantIds.find((id) => id !== message.senderId);
    if (!recipientId) return;

    const [senderSnap, recipientSnap] = await Promise.all([
      db.collection("playerProfiles").doc(message.senderId).get(),
      db.collection("playerProfiles").doc(recipientId).get(),
    ]);
    const tokens = (recipientSnap.data()?.fcmTokens as string[]) ?? [];
    if (tokens.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: senderSnap.data()?.displayName ?? "New message",
        body: message.text,
        imageUrl: senderSnap.data()?.photoUrl,
      },
      data: { type: "chat_message", chatId },
    });
    const deadTokens = response.responses
      .map((r, i) =>
        r.error?.code === "messaging/registration-token-not-registered"
          ? tokens[i]
          : null,
      )
      .filter((t): t is string => t !== null);
    if (deadTokens.length > 0) {
      await recipientSnap.ref.update({
        fcmTokens: FieldValue.arrayRemove(...deadTokens),
      });
    }
  },
);
