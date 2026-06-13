"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, property, value) {
        parser.push('FT.CONFIG', 'SET', property, value);
    },
    transformReply: undefined
};
//# sourceMappingURL=CONFIG_SET.js.map