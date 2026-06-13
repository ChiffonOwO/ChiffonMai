"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, slots) {
        parser.push('CLUSTER', 'ADDSLOTS');
        parser.pushVariadicNumber(slots);
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_ADDSLOTS.js.map