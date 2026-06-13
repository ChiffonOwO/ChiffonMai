"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('ZRANDMEMBER');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=ZRANDMEMBER.js.map