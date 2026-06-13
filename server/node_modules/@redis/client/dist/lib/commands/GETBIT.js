"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, offset) {
        parser.push('GETBIT');
        parser.pushKey(key);
        parser.push(offset.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=GETBIT.js.map