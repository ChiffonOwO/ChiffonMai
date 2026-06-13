"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, options) {
        parser.push('JSON.STRLEN');
        parser.pushKey(key);
        if (options?.path) {
            parser.push(options.path);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=STRLEN.js.map