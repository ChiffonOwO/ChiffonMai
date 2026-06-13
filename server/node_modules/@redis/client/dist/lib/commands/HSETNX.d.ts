import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, field: RedisArgument, value: RedisArgument) => void;
    readonly transformReply: () => NumberReply<0 | 1>;
};
export default _default;
//# sourceMappingURL=HSETNX.d.ts.map