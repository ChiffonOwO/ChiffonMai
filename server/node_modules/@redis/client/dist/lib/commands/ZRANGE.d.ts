import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, BlobStringReply } from '../RESP/types';
export interface ZRangeOptions {
    BY?: 'SCORE' | 'LEX';
    REV?: boolean;
    LIMIT?: {
        offset: number;
        count: number;
    };
}
export declare function zRangeArgument(min: RedisArgument | number, max: RedisArgument | number, options?: ZRangeOptions): RedisArgument[];
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, min: RedisArgument | number, max: RedisArgument | number, options?: ZRangeOptions) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply>;
};
export default _default;
//# sourceMappingURL=ZRANGE.d.ts.map