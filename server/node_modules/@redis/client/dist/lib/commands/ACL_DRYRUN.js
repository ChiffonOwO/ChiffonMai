"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, username, command) {
        parser.push('ACL', 'DRYRUN', username, ...command);
    },
    transformReply: undefined
};
//# sourceMappingURL=ACL_DRYRUN.js.map