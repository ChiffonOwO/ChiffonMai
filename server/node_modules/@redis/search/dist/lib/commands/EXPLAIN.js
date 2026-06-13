"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const SEARCH_1 = require("./SEARCH");
const default_1 = require("../dialect/default");
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, index, query, options) {
        parser.push('FT.EXPLAIN', index, query);
        (0, SEARCH_1.parseParamsArgument)(parser, options?.PARAMS);
        if (options?.DIALECT) {
            parser.push('DIALECT', options.DIALECT.toString());
        }
        else {
            parser.push('DIALECT', default_1.DEFAULT_DIALECT);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=EXPLAIN.js.map