"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key) {
        parser.push('TOUCH');
        parser.pushKeys(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=TOUCH.js.map