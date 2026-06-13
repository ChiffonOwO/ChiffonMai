"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, timeout) {
        parser.push('BLPOP');
        parser.pushKeys(key);
        parser.push(timeout.toString());
    },
    transformReply(reply) {
        if (reply === null)
            return null;
        return {
            key: reply[0],
            element: reply[1]
        };
    }
};
//# sourceMappingURL=BLPOP.js.map