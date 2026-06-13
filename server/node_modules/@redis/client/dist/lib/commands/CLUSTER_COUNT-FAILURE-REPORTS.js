"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, nodeId) {
        parser.push('CLUSTER', 'COUNT-FAILURE-REPORTS', nodeId);
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_COUNT-FAILURE-REPORTS.js.map