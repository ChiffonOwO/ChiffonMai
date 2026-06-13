"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, path) {
        parser.push('JSON.TOGGLE');
        parser.pushKey(key);
        parser.push(path);
    },
    transformReply: undefined
};
//# sourceMappingURL=TOGGLE.js.map