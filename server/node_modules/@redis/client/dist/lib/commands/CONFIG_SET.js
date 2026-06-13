"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser, ...[parameterOrConfig, value]) {
        parser.push('CONFIG', 'SET');
        if (typeof parameterOrConfig === 'string' || parameterOrConfig instanceof Buffer) {
            parser.push(parameterOrConfig, value);
        }
        else {
            for (const [key, value] of Object.entries(parameterOrConfig)) {
                parser.push(key, value);
            }
        }
    },
    transformReply: undefined
};
//# sourceMappingURL=CONFIG_SET.js.map