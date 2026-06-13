"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, count) {
        parser.push('HRANDFIELD');
        parser.pushKey(key);
        parser.push(count.toString(), 'WITHVALUES');
    },
    transformReply: {
        2: (rawReply) => {
            const reply = [];
            let i = 0;
            while (i < rawReply.length) {
                reply.push({
                    field: rawReply[i++],
                    value: rawReply[i++]
                });
            }
            return reply;
        },
        3: (reply) => {
            return reply.map(entry => {
                const [field, value] = entry;
                return {
                    field,
                    value
                };
            });
        }
    }
};
//# sourceMappingURL=HRANDFIELD_COUNT_WITHVALUES.js.map