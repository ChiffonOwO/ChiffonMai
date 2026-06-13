"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, seconds, value) {
        parser.push('SETEX');
        parser.pushKey(key);
        parser.push(seconds.toString(), value);
    },
    transformReply: undefined
};
//# sourceMappingURL=SETEX.js.map