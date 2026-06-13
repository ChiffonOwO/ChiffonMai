"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, index, fieldName) {
        parser.push('FT.TAGVALS', index, fieldName);
    },
    transformReply: {
        2: undefined,
        3: undefined
    }
};
//# sourceMappingURL=TAGVALS.js.map