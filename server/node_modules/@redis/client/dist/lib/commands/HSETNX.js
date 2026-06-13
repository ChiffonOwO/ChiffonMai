"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, field, value) {
        parser.push('HSETNX');
        parser.pushKey(key);
        parser.push(field, value);
    },
    transformReply: undefined
};
//# sourceMappingURL=HSETNX.js.map