"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseGeoRadiusByMemberArguments = void 0;
const GEOSEARCH_1 = require("./GEOSEARCH");
function parseGeoRadiusByMemberArguments(parser, key, from, radius, unit, options) {
    parser.pushKey(key);
    parser.push(from, radius.toString(), unit);
    (0, GEOSEARCH_1.parseGeoSearchOptions)(parser, options);
}
exports.parseGeoRadiusByMemberArguments = parseGeoRadiusByMemberArguments;
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, from, radius, unit, options) {
        parser.push('GEORADIUSBYMEMBER');
        parseGeoRadiusByMemberArguments(parser, key, from, radius, unit, options);
    },
    transformReply: undefined
};
//# sourceMappingURL=GEORADIUSBYMEMBER.js.map