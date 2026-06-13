"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ASKING_CMD = void 0;
exports.ASKING_CMD = 'ASKING';
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser) {
        parser.push(exports.ASKING_CMD);
    },
    transformReply: undefined
};
//# sourceMappingURL=ASKING.js.map