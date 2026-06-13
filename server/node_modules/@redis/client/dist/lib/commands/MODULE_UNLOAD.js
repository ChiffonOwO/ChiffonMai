"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, name) {
        parser.push('MODULE', 'UNLOAD', name);
    },
    transformReply: undefined
};
//# sourceMappingURL=MODULE_UNLOAD.js.map