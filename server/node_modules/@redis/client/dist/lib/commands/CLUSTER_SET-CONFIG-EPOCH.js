"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, configEpoch) {
        parser.push('CLUSTER', 'SET-CONFIG-EPOCH', configEpoch.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_SET-CONFIG-EPOCH.js.map