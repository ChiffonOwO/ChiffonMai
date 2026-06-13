import { CommandParser } from '../client/parser';
import { NumberReply, NullReply, RedisArgument } from '../RESP/types';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, member: RedisArgument) => void;
    readonly transformReply: () => NumberReply | NullReply;
};
export default _default;
//# sourceMappingURL=ZREVRANK.d.ts.map