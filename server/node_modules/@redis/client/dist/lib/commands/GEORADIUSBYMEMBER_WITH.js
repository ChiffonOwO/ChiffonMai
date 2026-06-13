"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseGeoRadiusByMemberWithArguments = void 0;
const GEORADIUSBYMEMBER_1 = __importDefault(require("./GEORADIUSBYMEMBER"));
const GEOSEARCH_1 = require("./GEOSEARCH");
const GEOSEARCH_WITH_1 = __importDefault(require("./GEOSEARCH_WITH"));
function parseGeoRadiusByMemberWithArguments(parser, key, from, radius, unit, replyWith, options) {
    parser.pushKey(key);
    parser.push(from, radius.toString(), unit);
    (0, GEOSEARCH_1.parseGeoSearchOptions)(parser, options);
    parser.push(...replyWith);
    parser.preserve = replyWith;
}
exports.parseGeoRadiusByMemberWithArguments = parseGeoRadiusByMemberWithArguments;
exports.default = {
    IS_READ_ONLY: GEORADIUSBYMEMBER_1.default.IS_READ_ONLY,
    parseCommand(parser, key, from, radius, unit, replyWith, options) {
        parser.push('GEORADIUSBYMEMBER');
        parseGeoRadiusByMemberWithArguments(parser, key, from, radius, unit, replyWith, options);
    },
    transformReply: GEOSEARCH_WITH_1.default.transformReply
};
//# sourceMappingURL=GEORADIUSBYMEMBER_WITH.js.map