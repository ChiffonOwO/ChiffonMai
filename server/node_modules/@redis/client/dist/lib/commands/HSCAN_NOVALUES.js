"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const HSCAN_1 = __importDefault(require("./HSCAN"));
exports.default = {
    IS_READ_ONLY: true,
    parseCommand(...args) {
        const parser = args[0];
        HSCAN_1.default.parseCommand(...args);
        parser.push('NOVALUES');
    },
    transformReply([cursor, fields]) {
        return {
            cursor,
            fields
        };
    }
};
//# sourceMappingURL=HSCAN_NOVALUES.js.map