"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const helpers_1 = require("./helpers");
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, fromTimestamp, toTimestamp) {
        parser.push('TS.DEL');
        parser.pushKey(key);
        parser.push((0, helpers_1.transformTimestampArgument)(fromTimestamp), (0, helpers_1.transformTimestampArgument)(toTimestamp));
    },
    transformReply: undefined
};
//# sourceMappingURL=DEL.js.map