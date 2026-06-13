"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, start, end) {
        parser.push('GETRANGE');
        parser.pushKey(key);
        parser.push(start.toString(), end.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=GETRANGE.js.map