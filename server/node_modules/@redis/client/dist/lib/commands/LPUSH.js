"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, elements) {
        parser.push('LPUSH');
        parser.pushKey(key);
        parser.pushVariadic(elements);
    },
    transformReply: undefined
};
//# sourceMappingURL=LPUSH.js.map