"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, keys) {
        parser.push('SDIFF');
        parser.pushKeys(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=SDIFF.js.map