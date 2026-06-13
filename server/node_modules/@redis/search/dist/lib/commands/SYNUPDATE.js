"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, index, groupId, terms, options) {
        parser.push('FT.SYNUPDATE', index, groupId);
        if (options?.SKIPINITIALSCAN) {
            parser.push('SKIPINITIALSCAN');
        }
        parser.pushVariadic(terms);
    },
    transformReply: undefined
};
//# sourceMappingURL=SYNUPDATE.js.map