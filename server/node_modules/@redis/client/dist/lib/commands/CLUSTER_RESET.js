"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, options) {
        parser.push('CLUSTER', 'RESET');
        if (options?.mode) {
            parser.push(options.mode);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_RESET.js.map