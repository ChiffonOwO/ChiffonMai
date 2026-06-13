"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, index, element) {
        parser.push('LSET');
        parser.pushKey(key);
        parser.push(index.toString(), element);
    },
    transformReply: undefined
};
//# sourceMappingURL=LSET.js.map