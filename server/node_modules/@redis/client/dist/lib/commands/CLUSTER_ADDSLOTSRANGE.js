"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, ranges) {
        parser.push('CLUSTER', 'ADDSLOTSRANGE');
        (0, generic_transformers_1.parseSlotRangesArguments)(parser, ranges);
    },
    transformReply: undefined
};
//# sourceMappingURL=CLUSTER_ADDSLOTSRANGE.js.map