import { initializeApp } from "firebase-admin/app";

initializeApp();

export { acceptRequest } from "./matching/acceptrequest";
export { declineRequest } from "./matching/declinerequest";
export { proposeMatch } from "./matching/proposematch";
export { reconcileScore } from "./scoring/reconcilescore";
export { submitScore } from "./scoring/submitscore";
