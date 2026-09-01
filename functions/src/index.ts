import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions";

initializeApp();

setGlobalOptions({ region: "europe-west1" });

export { acceptRequest } from "./matching/acceptrequest";
export { cancelMatch } from "./matching/cancelmatch";
export { cancelRequest } from "./matching/cancelrequest";
export { declineRequest } from "./matching/declinerequest";
export { proposeMatch } from "./matching/proposematch";
export { startMatch } from "./matching/startmatch";
export { updateMatchRequest } from "./matching/updatematchrequest";
export { onChatMessageCreated } from "./notifications/onchatmessage";
export { onMatchRequestCreated } from "./notifications/onmatchrequest";
export { onUserCreation } from "./onusercreation";
export { reconcileScore } from "./scoring/reconcilescore";
export { submitScore } from "./scoring/submitscore";
//export {expireStaleRequests} from "./maintenance/expireStaleRequests";
export { setUserStatus } from "./setuserstatus";
