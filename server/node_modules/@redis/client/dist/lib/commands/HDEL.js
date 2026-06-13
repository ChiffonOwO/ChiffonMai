"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, field) {
        parser.push('HDEL');
        parser.pushKey(key);
        parser.pushVariadic(field);
    },
    transformReply: undefined
};
//# sourceMappingURL=HDEL.js.map