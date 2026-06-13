import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, ms: number, mode?: 'NX' | 'XX' | 'GT' | 'LT') => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=PEXPIRE.d.ts.map