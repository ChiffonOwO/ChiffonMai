"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('HRANDFIELD');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=HRANDFIELD.js.map