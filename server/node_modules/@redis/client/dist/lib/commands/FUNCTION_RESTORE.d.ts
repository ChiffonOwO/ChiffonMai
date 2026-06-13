import { CommandParser } from '../client/parser';
import { SimpleStringReply, RedisArgument } from '../RESP/types';
export interface FunctionRestoreOptions {
    mode?: 'FLUSH' | 'APPEND' | 'REPLACE';
}
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, dump: RedisArgument, options?: FunctionRestoreOptions) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=FUNCTION_RESTORE.d.ts.map