"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, args) {
        parser.push('COMMAND', 'GETKEYS');
        parser.push(...args);
    },
    transformReply: undefined
};
//# sourceMappingURL=COMMAND_GETKEYS.js.map