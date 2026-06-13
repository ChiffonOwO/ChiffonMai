"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, username, rule) {
        parser.push('ACL', 'SETUSER', username);
        parser.pushVariadic(rule);
    },
    transformReply: undefined
};
//# sourceMappingURL=ACL_SETUSER.js.map