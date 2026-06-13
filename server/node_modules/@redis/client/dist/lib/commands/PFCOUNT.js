"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, keys) {
        parser.push('PFCOUNT');
        parser.pushKeys(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=PFCOUNT.js.map