import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply } from '../RESP/types';
export interface FunctionLoadOptions {
    REPLACE?: boolean;
}
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, code: RedisArgument, options?: FunctionLoadOptions) => void;
    readonly transformReply: () => BlobStringReply;
};
export default _default;
//# sourceMappingURL=FUNCTION_LOAD.d.ts.map