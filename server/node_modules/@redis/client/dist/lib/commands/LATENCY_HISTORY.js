"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, event) {
        parser.push('LATENCY', 'HISTORY', event);
    },
    transformReply: undefined
};
//# sourceMappingURL=LATENCY_HISTORY.js.map