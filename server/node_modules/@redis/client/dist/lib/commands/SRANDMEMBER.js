"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('SRANDMEMBER');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=SRANDMEMBER.js.map