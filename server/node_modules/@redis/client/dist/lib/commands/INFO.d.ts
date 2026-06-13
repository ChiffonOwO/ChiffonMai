import { CommandParser } from '../client/parser';
import { RedisArgument, VerbatimStringReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, section?: RedisArgument) => void;
    readonly transformReply: () => VerbatimStringReply;
};
export default _default;
//# sourceMappingURL=INFO.d.ts.map