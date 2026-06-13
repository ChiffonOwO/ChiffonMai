"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: false,
    parseCommand(parser, library) {
        parser.push('FUNCTION', 'DELETE', library);
    },
    transformReply: undefined
};
//# sourceMappingURL=FUNCTION_DELETE.js.map