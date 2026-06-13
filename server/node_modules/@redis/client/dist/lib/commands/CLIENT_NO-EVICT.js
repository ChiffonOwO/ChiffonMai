"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, value) {
        parser.push('CLIENT', 'NO-EVICT', value ? 'ON' : 'OFF');
    },
    transformReply: undefined
};
//# sourceMappingURL=CLIENT_NO-EVICT.js.map