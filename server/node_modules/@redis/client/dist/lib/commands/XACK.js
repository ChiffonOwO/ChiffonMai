"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, group, id) {
        parser.push('XACK');
        parser.pushKey(key);
        parser.push(group);
        parser.pushVariadic(id);
    },
    transformReply: undefined
};
//# sourceMappingURL=XACK.js.map