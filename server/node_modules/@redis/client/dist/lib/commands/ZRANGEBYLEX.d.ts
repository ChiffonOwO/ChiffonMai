import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, BlobStringReply } from '../RESP/types';
export interface ZRangeByLexOptions {
    LIMIT?: {
        offset: number;
        count: number;
    };
}
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, min: RedisArgument, max: RedisArgument, options?: ZRangeByLexOptions) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply>;
};
export default _default;
//# sourceMappingURL=ZRANGEBYLEX.d.ts.map