"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, element) {
        parser.push('PFADD');
        parser.pushKey(key);
        if (element) {
            parser.pushVariadic(element);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=PFADD.js.map