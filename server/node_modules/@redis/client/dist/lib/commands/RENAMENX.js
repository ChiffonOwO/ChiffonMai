"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, newKey) {
        parser.push('RENAMENX');
        parser.pushKeys([key, newKey]);
    },
    transformReply: undefined
};
//# sourceMappingURL=RENAMENX.js.map