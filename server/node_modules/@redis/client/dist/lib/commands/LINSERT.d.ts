import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
type LInsertPosition = 'BEFORE' | 'AFTER';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, position: LInsertPosition, pivot: RedisArgument, element: RedisArgument) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=LINSERT.d.ts.map