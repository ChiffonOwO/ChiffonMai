"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const MSET_1 = require("./MSET");
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, toSet) {
        parser.push('MSETNX');
        return (0, MSET_1.parseMSetArguments)(parser, toSet);
    },
    transformReply: undefined
};
//# sourceMappingURL=MSETNX.js.map