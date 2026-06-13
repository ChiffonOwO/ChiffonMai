"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, index) {
        parser.push('LINDEX');
        parser.pushKey(key);
        parser.push(index.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=LINDEX.js.map