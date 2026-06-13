"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const helpers_1 = require("./helpers");
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, toAdd) {
        parser.push('TS.MADD');
        for (const { key, timestamp, value } of toAdd) {
            parser.pushKey(key);
            parser.push((0, helpers_1.transformTimestampArgument)(timestamp), value.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=MADD.js.map