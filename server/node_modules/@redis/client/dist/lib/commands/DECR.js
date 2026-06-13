"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key) {
        parser.push('DECR');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=DECR.js.map