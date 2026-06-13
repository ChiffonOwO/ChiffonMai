import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, mode?: 'ASYNC' | 'SYNC') => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=SCRIPT_FLUSH.d.ts.map