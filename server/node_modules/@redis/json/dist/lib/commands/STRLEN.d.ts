import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { RedisArgument, ArrayReply, NumberReply, NullReply } from '@redis/client/dist/lib/RESP/types';
export interface JsonStrLenOptions {
    path?: RedisArgument;
}
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, options?: JsonStrLenOptions) => void;
    readonly transformReply: () => NumberReply | ArrayReply<NumberReply | NullReply>;
};
export default _default;
//# sourceMappingURL=STRLEN.d.ts.map