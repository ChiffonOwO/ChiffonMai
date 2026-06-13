"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, member) {
        parser.push('GEOPOS');
        parser.pushKey(key);
        parser.pushVariadic(member);
    },
    transformReply(reply) {
        return reply.map(item => {
            const unwrapped = item;
            return unwrapped === null ? null : {
                longitude: unwrapped[0],
                latitude: unwrapped[1]
            };
        });
    }
};
//# sourceMappingURL=GEOPOS.js.map