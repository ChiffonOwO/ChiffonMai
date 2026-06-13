"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, args) {
        parser.push('COMMAND', 'GETKEYSANDFLAGS');
        parser.push(...args);
    },
    transformReply(reply) {
        return reply.map(entry => {
            const [key, flags] = entry;
            return {
                key,
                flags
            };
        });
    }
};
//# sourceMappingURL=COMMAND_GETKEYSANDFLAGS.js.map