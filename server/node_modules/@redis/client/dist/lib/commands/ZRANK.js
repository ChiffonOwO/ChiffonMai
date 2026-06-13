"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, member) {
        parser.push('ZRANK');
        parser.pushKey(key);
        parser.push(member);
    },
    transformReply: undefined
};
//# sourceMappingURL=ZRANK.js.map