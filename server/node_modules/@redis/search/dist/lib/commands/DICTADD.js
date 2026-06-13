"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, dictionary, term) {
        parser.push('FT.DICTADD', dictionary);
        parser.pushVariadic(term);
    },
    transformReply: undefined
};
//# sourceMappingURL=DICTADD.js.map