"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, value) {
        parser.push('GETSET');
        parser.pushKey(key);
        parser.push(value);
    },
    transformReply: undefined
};
//# sourceMappingURL=GETSET.js.map