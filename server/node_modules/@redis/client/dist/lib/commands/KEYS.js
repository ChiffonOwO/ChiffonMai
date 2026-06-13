"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, pattern) {
        parser.push('KEYS', pattern);
    },
    transformReply: undefined
};
//# sourceMappingURL=KEYS.js.map