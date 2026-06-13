"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, newKey) {
        parser.push('RENAME');
        parser.pushKeys([key, newKey]);
    },
    transformReply: undefined
};
//# sourceMappingURL=RENAME.js.map