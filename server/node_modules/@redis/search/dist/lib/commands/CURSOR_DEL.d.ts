import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { SimpleStringReply, RedisArgument, NumberReply, UnwrapReply } from '@redis/client/dist/lib/RESP/types';
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, index: RedisArgument, cursorId: UnwrapReply<NumberReply>) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=CURSOR_DEL.d.ts.map