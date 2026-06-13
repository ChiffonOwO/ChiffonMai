"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, source, destination, options) {
        parser.push('COPY');
        parser.pushKeys([source, destination]);
        if (options?.DB) {
            parser.push('DB', options.DB.toString());
        }
        if (options?.REPLACE) {
            parser.push('REPLACE');
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=COPY.js.map