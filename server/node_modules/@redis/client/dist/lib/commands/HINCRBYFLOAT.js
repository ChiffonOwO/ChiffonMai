"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, field, increment) {
        parser.push('HINCRBYFLOAT');
        parser.pushKey(key);
        parser.push(field, increment.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=HINCRBYFLOAT.js.map