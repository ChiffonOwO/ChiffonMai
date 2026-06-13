"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, position, pivot, element) {
        parser.push('LINSERT');
        parser.pushKey(key);
        parser.push(position, pivot, element);
    },
    transformReply: undefined
};
//# sourceMappingURL=LINSERT.js.map