"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const ZINTER_1 = require("./ZINTER");
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, destination, keys, options) {
        parser.push('ZINTERSTORE');
        parser.pushKey(destination);
        (0, ZINTER_1.parseZInterArguments)(parser, keys, options);
    },
    transformReply: undefined
};
//# sourceMappingURL=ZINTERSTORE.js.map