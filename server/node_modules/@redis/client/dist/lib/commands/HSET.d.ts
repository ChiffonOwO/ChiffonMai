import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
export type HashTypes = RedisArgument | number;
type HSETObject = Record<string | number, HashTypes>;
type HSETMap = Map<HashTypes, HashTypes>;
type HSETTuples = Array<[HashTypes, HashTypes]> | Array<HashTypes>;
type GenericArguments = [key: RedisArgument];
type SingleFieldArguments = [...generic: GenericArguments, field: HashTypes, value: HashTypes];
type MultipleFieldsArguments = [...generic: GenericArguments, value: HSETObject | HSETMap | HSETTuples];
export type HSETArguments = SingleFieldArguments | MultipleFieldsArguments;
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, ...[key, value, fieldValue]: SingleFieldArguments | MultipleFieldsArguments) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=HSET.d.ts.map