"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.REDIS_FLUSH_MODES = void 0;
exports.REDIS_FLUSH_MODES = {
    ASYNC: 'ASYNC',
    SYNC: 'SYNC'
};
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: false,
    parseCommand(parser, mode) {
        parser.push('FLUSHALL');
        if (mode) {
            parser.push(mode);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=FLUSHALL.js.map