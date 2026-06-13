"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, ms, value) {
        parser.push('PSETEX');
        parser.pushKey(key);
        parser.push(ms.toString(), value);
    },
    transformReply: undefined
};
//# sourceMappingURL=PSETEX.js.map