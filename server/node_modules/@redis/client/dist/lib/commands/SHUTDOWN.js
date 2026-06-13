"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: false,
    parseCommand(parser, options) {
        parser.push('SHUTDOWN');
        if (options?.mode) {
            parser.push(options.mode);
        }
        if (options?.NOW) {
            parser.push('NOW');
        }
        if (options?.FORCE) {
            parser.push('FORCE');
        }
        if (options?.ABORT) {
            parser.push('ABORT');
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=SHUTDOWN.js.map