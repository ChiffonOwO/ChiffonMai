"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, pattern) {
        parser.push('PUBSUB', 'CHANNELS');
        if (pattern) {
            parser.push(pattern);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=PUBSUB_CHANNELS.js.map