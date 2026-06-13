"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const BLPOP_1 = __importDefault(require("./BLPOP"));
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(parser, key, timeout) {
        parser.push('BRPOP');
        parser.pushKeys(key);
        parser.push(timeout.toString());
    },
    transformReply: BLPOP_1.default.transformReply
};
//# sourceMappingURL=BRPOP.js.map