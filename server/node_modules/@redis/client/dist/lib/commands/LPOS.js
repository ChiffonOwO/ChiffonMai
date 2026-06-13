"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, element, options) {
        parser.push('LPOS');
        parser.pushKey(key);
        parser.push(element);
        if (options?.RANK !== undefined) {
            parser.push('RANK', options.RANK.toString());
        }
        if (options?.MAXLEN !== undefined) {
            parser.push('MAXLEN', options.MAXLEN.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=LPOS.js.map