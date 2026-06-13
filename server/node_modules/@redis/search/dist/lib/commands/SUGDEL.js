"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, string) {
        parser.push('FT.SUGDEL');
        parser.pushKey(key);
        parser.push(string);
    },
    transformReply: undefined
};
//# sourceMappingURL=SUGDEL.js.map