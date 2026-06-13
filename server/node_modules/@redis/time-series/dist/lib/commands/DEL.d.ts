import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { Timestamp } from './helpers';
import { RedisArgument, NumberReply } from '@redis/client/dist/lib/RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fromTimestamp: Timestamp, toTimestamp: Timestamp) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=DEL.d.ts.map