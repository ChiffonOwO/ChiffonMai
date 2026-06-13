import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, decrement: number) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=DECRBY.d.ts.map