"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, options) {
        parser.push('BGSAVE');
        if (options?.SCHEDULE) {
            parser.push('SCHEDULE');
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=BGSAVE.js.map