"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: false,
    parseCommand(parser) {
        parser.push('MEMORY', 'PURGE');
    },
    transformReply: undefined
};
//# sourceMappingURL=MEMORY_PURGE.js.map