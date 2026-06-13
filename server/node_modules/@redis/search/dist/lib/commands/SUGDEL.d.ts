import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { RedisArgument, NumberReply } from '@redis/client/dist/lib/RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, string: RedisArgument) => void;
    readonly transformReply: () => NumberReply<0 | 1>;
};
export default _default;
//# sourceMappingURL=SUGDEL.d.ts.map