"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, element) {
        parser.push('RPUSHX');
        parser.pushKey(key);
        parser.pushVariadic(element);
    },
    transformReply: undefined
};
//# sourceMappingURL=RPUSHX.js.map