"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, host, port) {
        parser.push('REPLICAOF', host, port.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=REPLICAOF.js.map