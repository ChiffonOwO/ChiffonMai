"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, count) {
        parser.push('HRANDFIELD');
        parser.pushKey(key);
        parser.push(count.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=HRANDFIELD_COUNT.js.map