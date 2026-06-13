"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, min, max) {
        parser.push('ZLEXCOUNT');
        parser.pushKey(key);
        parser.push(min);
        parser.push(max);
    },
    transformReply: undefined
};
//# sourceMappingURL=ZLEXCOUNT.js.map