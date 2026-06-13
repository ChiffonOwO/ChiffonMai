"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, range) {
        parser.push('BITCOUNT');
        parser.pushKey(key);
        if (range) {
            parser.push(range.start.toString());
            parser.push(range.end.toString());
            if (range.mode) {
                parser.push(range.mode);
            }
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=BITCOUNT.js.map