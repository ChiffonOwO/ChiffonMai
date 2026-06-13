"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, offset, value) {
        parser.push('SETRANGE');
        parser.pushKey(key);
        parser.push(offset.toString(), value);
    },
    transformReply: undefined
};
//# sourceMappingURL=SETRANGE.js.map