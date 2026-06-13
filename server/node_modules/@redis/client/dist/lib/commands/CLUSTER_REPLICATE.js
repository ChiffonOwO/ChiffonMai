"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, nodeId) {
        parser.push('CLUSTER', 'REPLICATE', nodeId);
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_REPLICATE.js.map