"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, string, score, options) {
        parser.push('FT.SUGADD');
        parser.pushKey(key);
        parser.push(string, score.toString());
        if (options?.INCR) {
            parser.push('INCR');
        }
        if (options?.PAYLOAD) {
            parser.push('PAYLOAD', options.PAYLOAD);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=SUGADD.js.map