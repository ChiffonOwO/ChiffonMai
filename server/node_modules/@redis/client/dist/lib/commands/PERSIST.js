"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key) {
        parser.push('PERSIST');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=PERSIST.js.map