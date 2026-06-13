"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseZInterArguments = void 0;
const generic_transformers_1 = require("./generic-transformers");
function parseZInterArguments(parser, keys, options) {
    (0, generic_transformers_1.parseZKeysArguments)(parser, keys);
    if (options?.AGGREGATE) {
        parser.push('AGGREGATE', options.AGGREGATE);
    }
}
exports.parseZInterArguments = parseZInterArguments;
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, keys, options) {
        parser.push('ZINTER');
        parseZInterArguments(parser, keys, options);
    },
    transformReply: undefined
};
//# sourceMappingURL=ZINTER.js.map