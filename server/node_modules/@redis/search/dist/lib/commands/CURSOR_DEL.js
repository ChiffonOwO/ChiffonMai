"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, index, cursorId) {
        parser.push('FT.CURSOR', 'DEL', index, cursorId.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=CURSOR_DEL.js.map