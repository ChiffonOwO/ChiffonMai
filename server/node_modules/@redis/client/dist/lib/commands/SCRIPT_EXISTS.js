"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, sha1) {
        parser.push('SCRIPT', 'EXISTS');
        parser.pushVariadic(sha1);
    },
    transformReply: undefined
};
//# sourceMappingURL=SCRIPT_EXISTS.js.map