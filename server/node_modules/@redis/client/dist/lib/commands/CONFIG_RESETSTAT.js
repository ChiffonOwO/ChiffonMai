"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser) {
        parser.push('CONFIG', 'RESETSTAT');
    },
    transformReply: undefined
};
//# sourceMappingURL=CONFIG_RESETSTAT.js.map