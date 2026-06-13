"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, keys) {
        parser.push('SINTER');
        parser.pushKeys(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=SINTER.js.map