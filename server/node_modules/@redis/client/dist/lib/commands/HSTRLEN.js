"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, field) {
        parser.push('HSTRLEN');
        parser.pushKey(key);
        parser.push(field);
    },
    transformReply: undefined
};
//# sourceMappingURL=HSTRLEN.js.map