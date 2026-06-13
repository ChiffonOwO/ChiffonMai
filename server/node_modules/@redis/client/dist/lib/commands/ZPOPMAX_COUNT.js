"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, count) {
        parser.push('ZPOPMAX');
        parser.pushKey(key);
        parser.push(count.toString());
    },
    transformReply: generic_transformers_1.transformSortedSetReply
};
//# sourceMappingURL=ZPOPMAX_COUNT.js.map