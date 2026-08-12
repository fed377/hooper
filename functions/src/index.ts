import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions";

initializeApp();

setGlobalOptions({region: "europe-west1"});

export { acceptRequest } from "./matching/acceptrequest";
export { cancelMatch } from "./matching/cancelmatch";
export { declineRequest } from "./matching/declinerequest";
export { proposeMatch } from "./matching/proposematch";
export { reconcileScore } from "./scoring/reconcilescore";
export { submitScore } from "./scoring/submitscore";
export { cancelRequest } from "./matching/cancelrequest";
export { updateMatchRequest } from "./matching/updatematchrequest"; 
export { onUserCreate } from "./onusercreate";
//export {expireStaleRequests} from "./maintenance/expireStaleRequests";


