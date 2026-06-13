"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser) {
        parser.push('LATENCY', 'LATEST');
    },
    transformReply: undefined
};
//# sourceMappingURL=LATENCY_LATEST.js.map