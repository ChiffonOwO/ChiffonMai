"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, value) {
        parser.push('CLIENT', 'CACHING', value ? 'YES' : 'NO');
    },
    transformReply: undefined
};
//# sourceMappingURL=CLIENT_CACHING.js.map