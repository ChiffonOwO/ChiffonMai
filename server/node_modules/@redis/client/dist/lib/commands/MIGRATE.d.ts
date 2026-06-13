import { CommandParser } from '../client/parser';
import { RedisArgument, SimpleStringReply } from '../RESP/types';
import { AuthOptions } from './AUTH';
export interface MigrateOptions {
    COPY?: true;
    REPLACE?: true;
    AUTH?: AuthOptions;
}
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, host: RedisArgument, port: number, key: RedisArgument | Array<RedisArgument>, destinationDb: number, timeout: number, options?: MigrateOptions) => void;
    readonly transformReply: () => SimpleStringReply<'OK'>;
};
export default _default;
//# sourceMappingURL=MIGRATE.d.ts.map