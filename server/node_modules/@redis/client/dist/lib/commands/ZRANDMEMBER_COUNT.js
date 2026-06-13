"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const ZRANDMEMBER_1 = __importDefault(require("./ZRANDMEMBER"));
exports.default = {
    IS_READ_ONLY: ZRANDMEMBER_1.default.IS_READ_ONLY,
    parseCommand(parser, key, count) {
        ZRANDMEMBER_1.default.parseCommand(parser, key);
        parser.push(count.toString());
    },
    transformReply: undefined
};
//# sourceMappingURL=ZRANDMEMBER_COUNT.js.map