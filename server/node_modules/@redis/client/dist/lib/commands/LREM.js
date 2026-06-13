"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, count, element) {
        parser.push('LREM');
        parser.pushKey(key);
        parser.push(count.toString());
        parser.push(element);
    },
    transformReply: undefined
};
//# sourceMappingURL=LREM.js.map