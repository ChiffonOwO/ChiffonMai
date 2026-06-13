"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, bit, start, end, mode) {
        parser.push('BITPOS');
        parser.pushKey(key);
        parser.push(bit.toString());
        if (start !== undefined) {
            parser.push(start.toString());
        }
        if (end !== undefined) {
            parser.push(end.toString());
        }
        if (mode) {
            parser.push(mode);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=BITPOS.js.map