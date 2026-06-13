"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, ms, mode) {
        parser.push('PEXPIRE');
        parser.pushKey(key);
        parser.push(ms.toString());
        if (mode) {
            parser.push(mode);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=PEXPIRE.js.map