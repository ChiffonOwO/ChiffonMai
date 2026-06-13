"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, keys) {
        parser.push('ZDIFF');
        parser.pushKeysLength(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=ZDIFF.js.map