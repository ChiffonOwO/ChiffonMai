import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { RedisArgument, ArrayReply, NumberReply, DoubleReply, NullReply, BlobStringReply, UnwrapReply } from '@redis/client/dist/lib/RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, path: RedisArgument, by: number) => void;
    readonly transformReply: {
        readonly 2: (reply: UnwrapReply<BlobStringReply>) => number | (number | null)[];
        readonly 3: () => ArrayReply<NumberReply | DoubleReply | NullReply>;
    };
};
export default _default;
//# sourceMappingURL=NUMINCRBY.d.ts.map