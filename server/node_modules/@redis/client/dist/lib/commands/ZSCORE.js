"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, member) {
        parser.push('ZSCORE');
        parser.pushKey(key);
        parser.push(member);
    },
    transformReply: generic_transformers_1.transformNullableDoubleReply
};
//# sourceMappingURL=ZSCORE.js.map