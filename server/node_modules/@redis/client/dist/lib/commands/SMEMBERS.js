"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('SMEMBERS');
        parser.pushKey(key);
    },
    transformReply: {
        2: undefined,
        3: undefined
    }
};
//# sourceMappingURL=SMEMBERS.js.map