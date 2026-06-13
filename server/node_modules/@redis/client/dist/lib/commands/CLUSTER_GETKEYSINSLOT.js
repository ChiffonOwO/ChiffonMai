"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, slot, count) {
        parser.push('CLUSTER', 'GETKEYSINSLOT', slot.toString(), count.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_GETKEYSINSLOT.js.map