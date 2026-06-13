"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, field, increment) {
        parser.push('HINCRBY');
        parser.pushKey(key);
        parser.push(field, increment.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=HINCRBY.js.map