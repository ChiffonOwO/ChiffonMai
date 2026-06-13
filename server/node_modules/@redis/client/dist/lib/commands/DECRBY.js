"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, decrement) {
        parser.push('DECRBY');
        parser.pushKey(key);
        parser.push(decrement.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=DECRBY.js.map