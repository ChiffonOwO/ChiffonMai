import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
interface FailoverOptions {
    TO?: {
        host: string;
        port: number;
        FORCE?: true;
    };
    ABORT?: true;
    TIMEOUT?: number;
}
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, options?: FailoverOptions) => void;
    readonly transformReply: () => SimpleStringReply;
};
export default _default;
//# sourceMappingURL=FAILOVER.d.ts.map