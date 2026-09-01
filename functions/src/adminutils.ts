import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

export function requireAdmin(request: CallableRequest): void {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }
}