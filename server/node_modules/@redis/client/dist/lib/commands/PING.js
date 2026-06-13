"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, message) {
        parser.push('PING');
        if (message) {
            parser.push(message);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=PING.js.map