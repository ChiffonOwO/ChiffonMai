import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=PTTL.d.ts.map