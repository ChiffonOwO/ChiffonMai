"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, script) {
        parser.push('SCRIPT', 'LOAD', script);
    },
    transformReply: undefined
};
//# sourceMappingURL=SCRIPT_LOAD.js.map