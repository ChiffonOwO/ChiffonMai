"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FAILOVER_MODES = void 0;
exports.FAILOVER_MODES = {
    FORCE: 'FORCE',
    TAKEOVER: 'TAKEOVER'
};
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, options) {
        parser.push('CLUSTER', 'FAILOVER');
        if (options?.mode) {
            parser.push(options.mode);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_FAILOVER.js.map