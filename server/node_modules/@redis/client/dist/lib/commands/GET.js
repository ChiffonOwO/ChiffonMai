"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key) {
        parser.push('GET');
        parser.pushKey(key);
    },
    transformReply: undefined
};
//# sourceMappingURL=GET.js.map