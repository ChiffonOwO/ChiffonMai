import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
import { RedisFlushMode } from './FLUSHALL';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, mode?: RedisFlushMode) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=FUNCTION_FLUSH.d.ts.map