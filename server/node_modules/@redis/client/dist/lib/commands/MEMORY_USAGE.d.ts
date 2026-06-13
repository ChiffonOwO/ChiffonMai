import { CommandParser } from '../client/parser';
import { NumberReply, NullReply, RedisArgument } from '../RESP/types';
export interface MemoryUsageOptions {
    SAMPLES?: number;
}
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, options?: MemoryUsageOptions) => void;
    readonly transformReply: () => NumberReply | NullReply;
};
export default _default;
//# sourceMappingURL=MEMORY_USAGE.d.ts.map