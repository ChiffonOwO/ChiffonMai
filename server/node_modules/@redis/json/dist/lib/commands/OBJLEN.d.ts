import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { RedisArgument, NumberReply, ArrayReply, NullReply } from '@redis/client/dist/lib/RESP/types';
export interface JsonObjLenOptions {
    path?: RedisArgument;
}
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, options?: JsonObjLenOptions) => void;
    readonly transformReply: () => NumberReply | ArrayReply<NumberReply | NullReply>;
};
export default _default;
//# sourceMappingURL=OBJLEN.d.ts.map