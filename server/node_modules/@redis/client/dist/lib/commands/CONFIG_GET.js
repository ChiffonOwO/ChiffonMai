"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, parameters) {
        parser.push('CONFIG', 'GET');
        parser.pushVariadic(parameters);
    },
    transformReply: {
        2: (generic_transformers_1.transformTuplesReply),
        3: undefined
    }
};
//# sourceMappingURL=CONFIG_GET.js.map