"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, keys, options) {
        parser.push('ZINTERCARD');
        parser.pushKeysLength(keys);
        // backwards compatibility
        if (typeof options === 'number') {
            parser.push('LIMIT', options.toString());
        }
        else if (options?.LIMIT) {
            parser.push('LIMIT', options.LIMIT.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=ZINTERCARD.js.map