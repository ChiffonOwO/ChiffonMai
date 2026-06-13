"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    parseCommand(parser, key, increment, member) {
        parser.push('ZINCRBY');
        parser.pushKey(key);
        parser.push((0, generic_transformers_1.transformDoubleArgument)(increment), member);
    },
    transformReply: generic_transformers_1.transformDoubleReply
};
//# sourceMappingURL=ZINCRBY.js.map