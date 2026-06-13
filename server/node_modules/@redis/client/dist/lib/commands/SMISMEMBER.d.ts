import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, NumberReply } from '../RESP/types';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, members: Array<RedisArgument>) => void;
    readonly transformReply: () => ArrayReply<NumberReply>;
};
export default _default;
//# sourceMappingURL=SMISMEMBER.d.ts.map