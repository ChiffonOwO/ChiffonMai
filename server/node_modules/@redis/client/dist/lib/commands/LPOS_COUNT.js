"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const LPOS_1 = __importDefault(require("./LPOS"));
exports.default = {
    CACHEABLE: LPOS_1.default.CACHEABLE,
    IS_READ_ONLY: LPOS_1.default.IS_READ_ONLY,
    parseCommand(parser, key, element, count, options) {
        LPOS_1.default.parseCommand(parser, key, element, options);
        parser.push('COUNT', count.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=LPOS_COUNT.js.map