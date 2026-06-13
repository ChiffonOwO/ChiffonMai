"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: false,
    parseCommand(parser, dump, options) {
        parser.push('FUNCTION', 'RESTORE', dump);
        if (options?.mode) {
            parser.push(options.mode);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=FUNCTION_RESTORE.js.map