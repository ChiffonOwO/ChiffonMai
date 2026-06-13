"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, ttl, serializedValue, options) {
        parser.push('RESTORE');
        parser.pushKey(key);
        parser.push(ttl.toString(), serializedValue);
        if (options?.REPLACE) {
            parser.push('REPLACE');
        }
        if (options?.ABSTTL) {
            parser.push('ABSTTL');
        }
        if (options?.IDLETIME) {
            parser.push('IDLETIME', options.IDLETIME.toString());
        }
        if (options?.FREQ) {
            parser.push('FREQ', options.FREQ.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=RESTORE.js.map