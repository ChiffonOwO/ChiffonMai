import { CommandParser } from '../client/parser';
import { SimpleStringReply } from '../RESP/types';
export interface BgSaveOptions {
    SCHEDULE?: boolean;
}
declare const _default: {
    readonly NOT_KEYED_COMMAND: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, options?: BgSaveOptions) => void;
    readonly transformReply: () => SimpleStringReply;
};
export default _default;
//# sourceMappingURL=BGSAVE.d.ts.map