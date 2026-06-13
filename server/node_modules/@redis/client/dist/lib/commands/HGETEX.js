"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    parseCommand(parser, key, fields, options) {
        parser.push('HGETEX');
        parser.pushKey(key);
        if (options?.expiration) {
            if (typeof options.expiration === 'string') {
                parser.push(options.expiration);
            }
            else if (options.expiration.type === 'PERSIST') {
                parser.push('PERSIST');
            }
            else {
                parser.push(options.expiration.type, options.expiration.value.toString());
            }
        }
        parser.push('FIELDS');
        parser.pushVariadicWithLength(fields);
    },
    transformReply: undefined
};
//# sourceMappingURL=HGETEX.js.map