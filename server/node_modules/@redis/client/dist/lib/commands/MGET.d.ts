import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply, NullReply } from '../RESP/types';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, keys: Array<RedisArgument>) => void;
    readonly transformReply: () => Array<BlobStringReply | NullReply>;
};
export default _default;
//# sourceMappingURL=MGET.d.ts.map