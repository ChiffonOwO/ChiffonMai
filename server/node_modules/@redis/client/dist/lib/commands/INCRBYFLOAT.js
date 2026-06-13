"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, increment) {
        parser.push('INCRBYFLOAT');
        parser.pushKey(key);
        parser.push(increment.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=INCRBYFLOAT.js.map