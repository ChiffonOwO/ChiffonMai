"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, name) {
        parser.push('CLIENT', 'SETNAME', name);
    },
    transformReply: undefined
};
//# sourceMappingURL=CLIENT_SETNAME.js.map