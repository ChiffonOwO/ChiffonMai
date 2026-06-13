"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, fields) {
        parser.push('HMGET');
        parser.pushKey(key);
        parser.pushVariadic(fields);
    },
    transformReply: undefined
};
//# sourceMappingURL=HMGET.js.map