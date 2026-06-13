"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, mode) {
        parser.push('SCRIPT', 'DEBUG', mode);
    },
    transformReply: undefined
};
//# sourceMappingURL=SCRIPT_DEBUG.js.map