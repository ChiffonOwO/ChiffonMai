"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, operation, destKey, key) {
        parser.push('BITOP', operation);
        parser.pushKey(destKey);
        parser.pushKeys(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=BITOP.js.map