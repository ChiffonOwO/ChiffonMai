import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, increment: number) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=INCRBY.d.ts.map