"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('FT.SUGLEN', key);
    },
    transformReply: undefined
};
//# sourceMappingURL=SUGLEN.js.map