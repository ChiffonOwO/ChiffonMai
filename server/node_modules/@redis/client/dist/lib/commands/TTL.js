"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('TTL');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=TTL.js.map