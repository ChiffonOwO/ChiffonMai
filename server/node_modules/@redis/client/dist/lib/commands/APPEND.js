"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, value) {
        parser.push('APPEND', key, value);
    },
    transformReply: undefined
};
//# sourceMappingURL=APPEND.js.map