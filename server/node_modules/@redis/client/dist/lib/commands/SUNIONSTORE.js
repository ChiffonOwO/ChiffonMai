"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, destination, keys) {
        parser.push('SUNIONSTORE');
        parser.pushKey(destination);
        parser.pushKeys(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=SUNIONSTORE.js.map