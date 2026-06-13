"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, prefix, options) {
        parser.push('FT.SUGGET');
        parser.pushKey(key);
        parser.push(prefix);
        if (options?.FUZZY) {
            parser.push('FUZZY');
        }
        if (options?.MAX !== undefined) {
            parser.push('MAX', options.MAX.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=SUGGET.js.map