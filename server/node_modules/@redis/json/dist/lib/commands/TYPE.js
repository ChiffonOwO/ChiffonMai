"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, options) {
        parser.push('JSON.TYPE');
        parser.pushKey(key);
        if (options?.path) {
            parser.push(options.path);
        }
    },
    transformReply: {
        2: undefined,
        // TODO: RESP3 wraps the response in another array, but only returns 1 
        3: (reply) => {
            return reply[0];
        }
    },
};
//# sourceMappingURL=TYPE.js.map