import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { NullReply, ArrayReply, BlobStringReply, RedisArgument } from '@redis/client/dist/lib/RESP/types';
export interface FtSugGetOptions {
    FUZZY?: boolean;
    MAX?: number;
}
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, prefix: RedisArgument, options?: FtSugGetOptions) => void;
    readonly transformReply: () => NullReply | ArrayReply<BlobStringReply>;
};
export default _default;
//# sourceMappingURL=SUGGET.d.ts.map