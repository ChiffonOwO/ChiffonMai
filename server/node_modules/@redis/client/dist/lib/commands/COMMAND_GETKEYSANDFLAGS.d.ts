import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, TuplesReply, BlobStringReply, SetReply, UnwrapReply } from '../RESP/types';
export type CommandGetKeysAndFlagsRawReply = ArrayReply<TuplesReply<[
    key: BlobStringReply,
    flags: SetReply<BlobStringReply>
]>>;
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, args: Array<RedisArgument>) => void;
    readonly transformReply: (this: void, reply: UnwrapReply<CommandGetKeysAndFlagsRawReply>) => {
        key: BlobStringReply<string>;
        flags: SetReply<BlobStringReply<string>>;
    }[];
};
export default _default;
//# sourceMappingURL=COMMAND_GETKEYSANDFLAGS.d.ts.map