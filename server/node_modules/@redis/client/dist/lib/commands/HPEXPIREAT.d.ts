import { CommandParser } from '../client/parser';
import { ArrayReply, NullReply, RedisArgument } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
import { HashExpiration } from './HEXPIRE';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: RedisVariadicArgument, timestamp: number | Date, mode?: 'NX' | 'XX' | 'GT' | 'LT') => void;
    readonly transformReply: () => ArrayReply<HashExpiration> | NullReply;
};
export default _default;
//# sourceMappingURL=HPEXPIREAT.d.ts.map