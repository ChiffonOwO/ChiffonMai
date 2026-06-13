"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, numberOfReplicas, timeout) {
        parser.push('WAIT', numberOfReplicas.toString(), timeout.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=WAIT.js.map