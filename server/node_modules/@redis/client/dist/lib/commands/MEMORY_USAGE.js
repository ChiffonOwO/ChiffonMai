"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, options) {
        parser.push('MEMORY', 'USAGE');
        parser.pushKey(key);
        if (options?.SAMPLES) {
            parser.push('SAMPLES', options.SAMPLES.toString());
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=MEMORY_USAGE.js.map