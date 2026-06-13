"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('HLEN');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=HLEN.js.map