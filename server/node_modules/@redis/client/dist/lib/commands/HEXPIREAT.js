"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    parseCommand(parser, key, fields, timestamp, mode) {
        parser.push('HEXPIREAT');
        parser.pushKey(key);
        parser.push((0, generic_transformers_1.transformEXAT)(timestamp));
        if (mode) {
            parser.push(mode);
        }
        parser.push('FIELDS');
        parser.pushVariadicWithLength(fields);
    },
    transformReply: undefined
};
//# sourceMappingURL=HEXPIREAT.js.map