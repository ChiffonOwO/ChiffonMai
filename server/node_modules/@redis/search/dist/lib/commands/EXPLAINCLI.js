"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const default_1 = require("../dialect/default");
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, index, query, options) {
        parser.push('FT.EXPLAINCLI', index, query);
        if (options?.DIALECT) {
            parser.push('DIALECT', options.DIALECT.toString());
        }
        else {
            parser.push('DIALECT', default_1.DEFAULT_DIALECT);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=EXPLAINCLI.js.map