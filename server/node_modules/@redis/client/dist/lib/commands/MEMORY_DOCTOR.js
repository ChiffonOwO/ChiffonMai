"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser) {
        parser.push('MEMORY', 'DOCTOR');
    },
    transformReply: undefined
};
//# sourceMappingURL=MEMORY_DOCTOR.js.map