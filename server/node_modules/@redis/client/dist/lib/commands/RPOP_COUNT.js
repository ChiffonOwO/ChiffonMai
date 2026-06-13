"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, count) {
        parser.push('RPOP');
        parser.pushKey(key);
        parser.push(count.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=RPOP_COUNT.js.map