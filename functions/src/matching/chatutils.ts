import {
  DocumentReference,
  DocumentSnapshot,
  FieldValue,
  Transaction,
} from "firebase-admin/firestore";

export function pairChatId(uidA: string, uidB: string): string {
  return [uidA, uidB].sort().join("_");
}

export async function ensureChatExists(
  tx: Transaction,
  chatRef: DocumentReference,
  uidA: string,
  uidB: string,
  existingSnap?: DocumentSnapshot,
): Promise<void> {
  const snap = existingSnap ?? (await tx.get(chatRef));
  if (snap.exists) return;
  tx.set(chatRef, {
    participantIds: [uidA, uidB].sort(),
    lastMatchRequestId: null,
    createdAt: FieldValue.serverTimestamp(),
    lastMessageAt: FieldValue.serverTimestamp(),
    lastMessagePreview: null,
  });
}
export function postSystemMessage(
  tx: Transaction,
  chatRef: DocumentReference,
  text: string,
  opts: { matchRequestId?: string; senderId?: string } = {},
): void {
  tx.set(chatRef.collection("messages").doc(), {
    isSystem: true,
    text,
    matchRequestId: opts.matchRequestId ?? null,
    senderId: opts.senderId ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
  tx.update(chatRef, {
    lastMessageAt: FieldValue.serverTimestamp(),
    lastMessagePreview: text,
  });
}
