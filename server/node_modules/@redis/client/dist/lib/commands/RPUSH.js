"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, element) {
        parser.push('RPUSH');
        parser.pushKey(key);
        parser.pushVariadic(element);
    },
    transformReply: undefined
};
//# sourceMappingURL=RPUSH.js.map