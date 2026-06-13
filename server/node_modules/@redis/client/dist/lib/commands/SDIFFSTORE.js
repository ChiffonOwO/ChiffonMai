"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, destination, keys) {
        parser.push('SDIFFSTORE');
        parser.pushKey(destination);
        parser.pushKeys(keys);
    },
    transformReply: undefined
};
//# sourceMappingURL=SDIFFSTORE.js.map