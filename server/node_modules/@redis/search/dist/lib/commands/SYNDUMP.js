"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, index) {
        parser.push('FT.SYNDUMP', index);
    },
    transformReply: {
        2: (reply) => {
            const result = {};
            let i = 0;
            while (i < reply.length) {
                const key = reply[i++].toString(), value = reply[i++];
                result[key] = value;
            }
            return result;
        },
        3: undefined
    }
};
//# sourceMappingURL=SYNDUMP.js.map