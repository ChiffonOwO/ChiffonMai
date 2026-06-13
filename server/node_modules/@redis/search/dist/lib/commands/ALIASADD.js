"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, alias, index) {
        parser.push('FT.ALIASADD', alias, index);
    },
    transformReply: undefined
};
//# sourceMappingURL=ALIASADD.js.map