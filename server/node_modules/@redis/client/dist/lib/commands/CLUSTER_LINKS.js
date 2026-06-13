"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser) {
        parser.push('CLUSTER', 'LINKS');
    },
    transformReply: {
        2: (reply) => reply.map(link => {
            const unwrapped = link;
            return {
                direction: unwrapped[1],
                node: unwrapped[3],
                'create-time': unwrapped[5],
                events: unwrapped[7],
                'send-buffer-allocated': unwrapped[9],
                'send-buffer-used': unwrapped[11]
            };
        }),
        3: undefined
    }
};
//# sourceMappingURL=CLUSTER_LINKS.js.map