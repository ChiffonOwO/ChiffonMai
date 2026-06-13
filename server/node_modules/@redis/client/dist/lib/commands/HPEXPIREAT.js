"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, fields, timestamp, mode) {
        parser.push('HPEXPIREAT');
        parser.pushKey(key);
        parser.push((0, generic_transformers_1.transformPXAT)(timestamp));
        if (mode) {
            parser.push(mode);
        }
        parser.push('FIELDS');
        parser.pushVariadicWithLength(fields);
    },
    transformReply: undefined
};
//# sourceMappingURL=HPEXPIREAT.js.map