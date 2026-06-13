import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly IS_FORWARD_COMMAND: true;
    readonly parseCommand: (this: void, parser: CommandParser, channel: RedisArgument, message: RedisArgument) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=PUBLISH.d.ts.map