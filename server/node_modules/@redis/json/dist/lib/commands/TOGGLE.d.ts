import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { RedisArgument, ArrayReply, NumberReply, NullReply } from '@redis/client/dist/lib/RESP/types';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, path: RedisArgument) => void;
    readonly transformReply: () => NumberReply | NullReply | ArrayReply<NumberReply | NullReply>;
};
export default _default;
//# sourceMappingURL=TOGGLE.d.ts.map