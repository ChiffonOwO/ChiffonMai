"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, username) {
        parser.push('ACL', 'DELUSER');
        parser.pushVariadic(username);
    },
    transformReply: undefined
};
//# sourceMappingURL=ACL_DELUSER.js.map