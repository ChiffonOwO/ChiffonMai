import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply, NullReply } from '../RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument) => void;
    readonly transformReply: () => NumberReply | NullReply;
};
export default _default;
//# sourceMappingURL=OBJECT_IDLETIME.d.ts.map