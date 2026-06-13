"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, elements) {
        parser.push('LPUSHX');
        parser.pushKey(key);
        parser.pushVariadic(elements);
    },
    transformReply: undefined
};
//# sourceMappingURL=LPUSHX.js.map