import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { RedisArgument, NullReply, NumberReply, ArrayReply } from '@redis/client/dist/lib/RESP/types';
export interface JsonStrAppendOptions {
    path?: RedisArgument;
}
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, append: string, options?: JsonStrAppendOptions) => void;
    readonly transformReply: () => NumberReply | ArrayReply<NullReply | NumberReply>;
};
export default _default;
//# sourceMappingURL=STRAPPEND.d.ts.map