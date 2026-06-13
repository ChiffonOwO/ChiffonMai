"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, dictionary, term) {
        parser.push('FT.DICTDEL', dictionary);
        parser.pushVariadic(term);
    },
    transformReply: undefined
};
//# sourceMappingURL=DICTDEL.js.map