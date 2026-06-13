import { CommandParser } from '../client/parser';
import { SimpleStringReply, RedisArgument } from '../RESP/types';
type SingleParameter = [parameter: RedisArgument, value: RedisArgument];
type MultipleParameters = [config: Record<string, RedisArgument>];
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, ...[parameterOrConfig, value]: SingleParameter | MultipleParameters) => void;
    readonly transformReply: () => SimpleStringReply;
};
export default _default;
//# sourceMappingURL=CONFIG_SET.d.ts.map