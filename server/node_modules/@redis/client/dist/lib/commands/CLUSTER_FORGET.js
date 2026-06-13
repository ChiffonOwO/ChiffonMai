"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, nodeId) {
        parser.push('CLUSTER', 'FORGET', nodeId);
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_FORGET.js.map