"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, categoryName) {
        parser.push('ACL', 'CAT');
        if (categoryName) {
            parser.push(categoryName);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=ACL_CAT.js.map