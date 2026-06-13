"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('CLUSTER', 'KEYSLOT', key);
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_KEYSLOT.js.map