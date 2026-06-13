import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
export interface ZRangeStoreOptions {
    BY?: 'SCORE' | 'LEX';
    REV?: true;
    LIMIT?: {
        offset: number;
        count: number;
    };
}
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, destination: RedisArgument, source: RedisArgument, min: RedisArgument | number, max: RedisArgument | number, options?: ZRangeStoreOptions) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=ZRANGESTORE.d.ts.map