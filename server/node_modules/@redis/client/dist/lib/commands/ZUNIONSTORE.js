"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, destination, keys, options) {
        parser.push('ZUNIONSTORE');
        parser.pushKey(destination);
        (0, generic_transformers_1.parseZKeysArguments)(parser, keys);
        if (options?.AGGREGATE) {
            parser.push('AGGREGATE', options.AGGREGATE);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=ZUNIONSTORE.js.map