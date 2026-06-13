"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseZMPopArguments = void 0;
const generic_transformers_1 = require("./generic-transformers");
function parseZMPopArguments(parser, keys, side, options) {
    parser.pushKeysLength(keys);
    parser.push(side);
    if (options?.COUNT) {
        parser.push('COUNT', options.COUNT.toString());
    }
}
exports.parseZMPopArguments = parseZMPopArguments;
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, keys, side, options) {
        parser.push('ZMPOP');
        parseZMPopArguments(parser, keys, side, options);
    },
    transformReply: {
        2(reply, preserve, typeMapping) {
            return reply === null ? null : {
                key: reply[0],
                members: reply[1].map(member => {
                    const [value, score] = member;
                    return {
                        value,
                        score: generic_transformers_1.transformDoubleReply[2](score, preserve, typeMapping)
                    };
                })
            };
        },
        3(reply) {
            return reply === null ? null : {
                key: reply[0],
                members: generic_transformers_1.transformSortedSetReply[3](reply[1])
            };
        }
    }
};
//# sourceMappingURL=ZMPOP.js.map