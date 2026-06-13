"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, members) {
        parser.push('SREM');
        parser.pushKey(key);
        parser.pushVariadic(members);
    },
    transformReply: undefined
};
//# sourceMappingURL=SREM.js.map