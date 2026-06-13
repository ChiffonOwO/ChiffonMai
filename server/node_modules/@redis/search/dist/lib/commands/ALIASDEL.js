"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, alias) {
        parser.push('FT.ALIASDEL', alias);
    },
    transformReply: undefined
};
//# sourceMappingURL=ALIASDEL.js.map