"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, alias, index) {
        parser.push('FT.ALIASUPDATE', alias, index);
    },
    transformReply: undefined
};
//# sourceMappingURL=ALIASUPDATE.js.map