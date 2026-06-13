"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, msTimestamp, mode) {
        parser.push('PEXPIREAT');
        parser.pushKey(key);
        parser.push((0, generic_transformers_1.transformPXAT)(msTimestamp));
        if (mode) {
            parser.push(mode);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=PEXPIREAT.js.map