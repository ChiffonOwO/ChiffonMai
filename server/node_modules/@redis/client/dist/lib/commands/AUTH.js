"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, { username, password }) {
        parser.push('AUTH');
        if (username !== undefined) {
            parser.push(username);
        }
        parser.push(password);
    },
    transformReply: undefined
};
//# sourceMappingURL=AUTH.js.map