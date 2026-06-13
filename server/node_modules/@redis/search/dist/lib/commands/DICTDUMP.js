"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, dictionary) {
        parser.push('FT.DICTDUMP', dictionary);
    },
    transformReply: {
        2: undefined,
        3: undefined
    }
};
//# sourceMappingURL=DICTDUMP.js.map