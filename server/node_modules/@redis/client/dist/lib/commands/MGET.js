"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, keys) {
        parser.push('MGET');
        parser.pushKeys(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=MGET.js.map