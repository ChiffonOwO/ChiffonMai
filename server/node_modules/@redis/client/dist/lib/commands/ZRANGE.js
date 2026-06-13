"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.zRangeArgument = void 0;
const generic_transformers_1 = require("./generic-transformers");
function zRangeArgument(min, max, options) {
    const args = [
        (0, generic_transformers_1.transformStringDoubleArgument)(min),
        (0, generic_transformers_1.transformStringDoubleArgument)(max)
    ];
    switch (options?.BY) {
        case 'SCORE':
            args.push('BYSCORE');
            break;
        case 'LEX':
            args.push('BYLEX');
            break;
    }
    if (options?.REV) {
        args.push('REV');
    }
    if (options?.LIMIT) {
        args.push('LIMIT', options.LIMIT.offset.toString(), options.LIMIT.count.toString());
    }
    return args;
}
exports.zRangeArgument = zRangeArgument;
exports.default = {
    CACHEABLE: true,
    IS_READ_ONLY: true,
    parseCommand(parser, key, min, max, options) {
        parser.push('ZRANGE');
        parser.pushKey(key);
        parser.pushVariadic(zRangeArgument(min, max, options));
    },
    transformReply: undefined
};
//# sourceMappingURL=ZRANGE.js.map