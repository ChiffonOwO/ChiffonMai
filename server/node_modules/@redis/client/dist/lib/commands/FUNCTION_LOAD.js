"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: false,
    parseCommand(parser, code, options) {
        parser.push('FUNCTION', 'LOAD');
        if (options?.REPLACE) {
            parser.push('REPLACE');
        }
        parser.push(code);
    },
    transformReply: undefined
};
//# sourceMappingURL=FUNCTION_LOAD.js.map