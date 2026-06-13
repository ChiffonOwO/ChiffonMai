"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const CREATE_1 = require("./CREATE");
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, index, schema) {
        parser.push('FT.ALTER', index, 'SCHEMA', 'ADD');
        (0, CREATE_1.parseSchema)(parser, schema);
    },
    transformReply: undefined
};
//# sourceMappingURL=ALTER.js.map