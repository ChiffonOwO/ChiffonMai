"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, keys) {
        parser.push('DEL');
        parser.pushKeys(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=DEL.js.map