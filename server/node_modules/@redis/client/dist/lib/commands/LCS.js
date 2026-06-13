"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key1, key2) {
        parser.push('LCS');
        parser.pushKeys([key1, key2]);
    },
    transformReply: undefined
};
//# sourceMappingURL=LCS.js.map