"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, increment) {
        parser.push('INCRBY');
        parser.pushKey(key);
        parser.push(increment.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=INCRBY.js.map