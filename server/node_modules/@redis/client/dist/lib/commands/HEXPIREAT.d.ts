import { CommandParser } from '../client/parser';
import { RedisVariadicArgument } from './generic-transformers';
import { ArrayReply, NumberReply, RedisArgument } from '../RESP/types';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: RedisVariadicArgument, timestamp: number | Date, mode?: 'NX' | 'XX' | 'GT' | 'LT') => void;
    readonly transformReply: () => ArrayReply<NumberReply>;
};
export default _default;
//# sourceMappingURL=HEXPIREAT.d.ts.map