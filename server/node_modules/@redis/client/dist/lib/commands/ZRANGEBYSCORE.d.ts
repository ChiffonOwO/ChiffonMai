import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, BlobStringReply } from '../RESP/types';
export interface ZRangeByScoreOptions {
    LIMIT?: {
        offset: number;
        count: number;
    };
}
export declare function transformReply(): Array<RedisArgument>;
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, min: string | number, max: string | number, options?: ZRangeByScoreOptions) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply>;
};
export default _default;
//# sourceMappingURL=ZRANGEBYSCORE.d.ts.map