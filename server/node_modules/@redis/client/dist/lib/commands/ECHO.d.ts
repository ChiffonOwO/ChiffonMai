import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, message: RedisArgument) => void;
    readonly transformReply: () => BlobStringReply;
};
export default _default;
//# sourceMappingURL=ECHO.d.ts.map