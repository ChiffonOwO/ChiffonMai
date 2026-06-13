import { CommandParser } from '../client/parser';
import { ArrayReply, NullReply, NumberReply, RedisArgument } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: RedisVariadicArgument) => void;
    readonly transformReply: () => ArrayReply<NumberReply> | NullReply;
};
export default _default;
//# sourceMappingURL=HPEXPIRETIME.d.ts.map