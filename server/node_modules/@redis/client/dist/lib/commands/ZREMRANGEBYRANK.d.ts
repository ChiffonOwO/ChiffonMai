import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, start: number, stop: number) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=ZREMRANGEBYRANK.d.ts.map