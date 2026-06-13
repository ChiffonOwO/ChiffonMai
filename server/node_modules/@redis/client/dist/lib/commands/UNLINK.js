"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, keys) {
        parser.push('UNLINK');
        parser.pushKeys(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=UNLINK.js.map