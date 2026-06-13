"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CLUSTER_SLOT_STATES = void 0;
exports.CLUSTER_SLOT_STATES = {
    IMPORTING: 'IMPORTING',
    MIGRATING: 'MIGRATING',
    STABLE: 'STABLE',
    NODE: 'NODE'
};
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, slot, state, nodeId) {
        parser.push('CLUSTER', 'SETSLOT', slot.toString(), state);
        if (nodeId) {
            parser.push(nodeId);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_SETSLOT.js.map