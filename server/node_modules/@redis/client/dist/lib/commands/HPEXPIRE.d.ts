import { CommandParser } from '../client/parser';
import { ArrayReply, NullReply, RedisArgument } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
import { HashExpiration } from './HEXPIRE';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: RedisVariadicArgument, ms: number, mode?: 'NX' | 'XX' | 'GT' | 'LT') => void;
    readonly transformReply: () => ArrayReply<HashExpiration> | NullReply;
};
export default _default;
//# sourceMappingURL=HPEXPIRE.d.ts.map