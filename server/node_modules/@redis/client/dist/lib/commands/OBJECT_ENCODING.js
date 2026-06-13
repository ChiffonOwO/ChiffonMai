"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('OBJECT', 'ENCODING');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=OBJECT_ENCODING.js.map