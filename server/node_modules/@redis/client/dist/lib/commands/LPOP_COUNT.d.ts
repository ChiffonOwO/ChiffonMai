import { CommandParser } from '../client/parser';
import { RedisArgument, NullReply, ArrayReply, BlobStringReply } from '../RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, count: number) => void;
    readonly transformReply: () => NullReply | ArrayReply<BlobStringReply>;
};
export default _default;
//# sourceMappingURL=LPOP_COUNT.d.ts.map