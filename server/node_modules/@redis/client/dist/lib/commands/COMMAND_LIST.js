"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.COMMAND_LIST_FILTER_BY = void 0;
exports.COMMAND_LIST_FILTER_BY = {
    MODULE: 'MODULE',
    ACLCAT: 'ACLCAT',
    PATTERN: 'PATTERN'
};
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, options) {
        parser.push('COMMAND', 'LIST');
        if (options?.FILTERBY) {
            parser.push('FILTERBY', options.FILTERBY.type, options.FILTERBY.value);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=COMMAND_LIST.js.map