"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const generic_transformers_1 = require("./generic-transformers");
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, member) {
        parser.push('ZMSCORE');
        parser.pushKey(key);
        parser.pushVariadic(member);
    },
    transformReply: {
        2: (reply, preserve, typeMapping) => {
            return reply.map((0, generic_transformers_1.createTransformNullableDoubleReplyResp2Func)(preserve, typeMapping));
        },
        3: undefined
    }
};
//# sourceMappingURL=ZMSCORE.js.map