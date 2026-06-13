"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, slot) {
        parser.push('CLUSTER', 'COUNTKEYSINSLOT', slot.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_COUNTKEYSINSLOT.js.map