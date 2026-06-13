"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, section) {
        parser.push('INFO');
        if (section) {
            parser.push(section);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=INFO.js.map