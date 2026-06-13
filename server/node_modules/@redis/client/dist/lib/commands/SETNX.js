"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, value) {
        parser.push('SETNX');
        parser.pushKey(key);
        parser.push(value);
    },
    transformReply: undefined
};
//# sourceMappingURL=SETNX.js.map