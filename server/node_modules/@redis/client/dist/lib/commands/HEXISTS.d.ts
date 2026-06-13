import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, field: RedisArgument) => void;
    readonly transformReply: () => NumberReply<0 | 1>;
};
export default _default;
//# sourceMappingURL=HEXISTS.d.ts.map