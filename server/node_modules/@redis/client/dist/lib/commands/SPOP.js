"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key) {
        parser.push('SPOP');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=SPOP.js.map