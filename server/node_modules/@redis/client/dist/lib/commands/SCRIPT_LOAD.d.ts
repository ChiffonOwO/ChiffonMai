import { CommandParser } from '../client/parser';
import { BlobStringReply, RedisArgument } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, script: RedisArgument) => void;
    readonly transformReply: () => BlobStringReply;
};
export default _default;
//# sourceMappingURL=SCRIPT_LOAD.d.ts.map