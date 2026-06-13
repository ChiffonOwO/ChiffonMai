"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, keys, options) {
        parser.push('ZUNION');
        (0, generic_transformers_1.parseZKeysArguments)(parser, keys);
        if (options?.AGGREGATE) {
            parser.push('AGGREGATE', options.AGGREGATE);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=ZUNION.js.map