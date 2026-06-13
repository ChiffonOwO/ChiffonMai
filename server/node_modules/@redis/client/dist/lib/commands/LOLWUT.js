"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, version, ...optionalArguments) {
        parser.push('LOLWUT');
        if (version) {
            parser.push('VERSION', version.toString());
            parser.pushVariadic(optionalArguments.map(String));
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=LOLWUT.js.map