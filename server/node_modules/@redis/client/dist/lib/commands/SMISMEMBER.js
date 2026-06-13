"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, members) {
        parser.push('SMISMEMBER');
        parser.pushKey(key);
        parser.pushVariadic(members);
    },
    transformReply: undefined
};
//# sourceMappingURL=SMISMEMBER.js.map