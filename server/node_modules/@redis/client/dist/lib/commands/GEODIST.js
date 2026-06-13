"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, member1, member2, unit) {
        parser.push('GEODIST');
        parser.pushKey(key);
        parser.push(member1, member2);
        if (unit) {
            parser.push(unit);
        }
    },
    transformReply(reply) {
        return reply === null ? null : Number(reply);
    }
};
//# sourceMappingURL=GEODIST.js.map