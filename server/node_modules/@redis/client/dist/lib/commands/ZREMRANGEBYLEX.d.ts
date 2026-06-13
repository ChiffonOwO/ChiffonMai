import { CommandParser } from '../client/parser';
import { NumberReply, RedisArgument } from '../RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, min: RedisArgument | number, max: RedisArgument | number) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=ZREMRANGEBYLEX.d.ts.map