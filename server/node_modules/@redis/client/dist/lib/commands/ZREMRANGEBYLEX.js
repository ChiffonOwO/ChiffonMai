"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, min, max) {
        parser.push('ZREMRANGEBYLEX');
        parser.pushKey(key);
        parser.push((0, generic_transformers_1.transformStringDoubleArgument)(min), (0, generic_transformers_1.transformStringDoubleArgument)(max));
    },
    transformReply: undefined
};
//# sourceMappingURL=ZREMRANGEBYLEX.js.map