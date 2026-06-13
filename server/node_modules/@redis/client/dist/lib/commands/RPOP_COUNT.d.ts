import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, BlobStringReply, NullReply } from '../RESP/types';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, count: number) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply> | NullReply;
};
export default _default;
//# sourceMappingURL=RPOP_COUNT.d.ts.map