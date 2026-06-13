"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, offset, value) {
        parser.push('SETBIT');
        parser.pushKey(key);
        parser.push(offset.toString(), value.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=SETBIT.js.map