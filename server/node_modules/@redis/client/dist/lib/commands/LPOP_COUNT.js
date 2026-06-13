"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const LPOP_1 = __importDefault(require("./LPOP"));
exports.default = {
    IS_READ_ONLY: false,
    parseCommand(parser, key, count) {
        LPOP_1.default.parseCommand(parser, key);
        parser.push(count.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=LPOP_COUNT.js.map