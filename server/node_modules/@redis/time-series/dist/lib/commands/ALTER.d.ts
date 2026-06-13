import { CommandParser } from '@redis/client/dist/lib/client/parser';
import { RedisArgument, SimpleStringReply } from '@redis/client/dist/lib/RESP/types';
import { TsCreateOptions } from './CREATE';
export type TsAlterOptions = Pick<TsCreateOptions, 'RETENTION' | 'CHUNK_SIZE' | 'DUPLICATE_POLICY' | 'LABELS' | 'IGNORE'>;
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, options?: TsAlterOptions) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=ALTER.d.ts.map