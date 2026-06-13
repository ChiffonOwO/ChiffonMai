"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser) {
        parser.push('ACL', 'LIST');
    },
    transformReply: undefined
};
//# sourceMappingURL=ACL_LIST.js.map