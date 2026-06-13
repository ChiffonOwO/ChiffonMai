import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, NumberReply } from '../RESP/types';
import { LPosOptions } from './LPOS';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, element: RedisArgument, count: number, options?: LPosOptions) => void;
    readonly transformReply: () => ArrayReply<NumberReply>;
};
export default _default;
//# sourceMappingURL=LPOS_COUNT.d.ts.map