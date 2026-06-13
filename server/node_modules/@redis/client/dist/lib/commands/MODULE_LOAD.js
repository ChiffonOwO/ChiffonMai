"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, path, moduleArguments) {
        parser.push('MODULE', 'LOAD', path);
        if (moduleArguments) {
            parser.push(...moduleArguments);
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=MODULE_LOAD.js.map