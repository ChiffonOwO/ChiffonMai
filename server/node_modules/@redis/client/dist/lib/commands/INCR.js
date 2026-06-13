"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key) {
        parser.push('INCR');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=INCR.js.map