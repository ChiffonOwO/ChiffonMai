"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, start, stop) {
        parser.push('LRANGE');
        parser.pushKey(key);
        parser.push(start.toString(), stop.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=LRANGE.js.map