"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key) {
        parser.push('RPOP');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=RPOP.js.map