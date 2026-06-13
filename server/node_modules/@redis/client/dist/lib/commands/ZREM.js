"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, member) {
        parser.push('ZREM');
        parser.pushKey(key);
        parser.pushVariadic(member);
    },
    transformReply: undefined
};
//# sourceMappingURL=ZREM.js.map