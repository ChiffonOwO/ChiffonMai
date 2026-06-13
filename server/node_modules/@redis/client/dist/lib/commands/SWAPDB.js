"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: false,
    parseCommand(parser, index1, index2) {
        parser.push('SWAPDB', index1.toString(), index2.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=SWAPDB.js.map