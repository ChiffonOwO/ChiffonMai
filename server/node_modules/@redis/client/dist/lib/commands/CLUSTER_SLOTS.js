"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    NOT_KEYED_COMMAND: true,
    IS_READ_ONLY: true,
    parseCommand(parser) {
        parser.push('CLUSTER', 'SLOTS');
    },
    transformReply(reply) {
        return reply.map(([from, to, master, ...replicas]) => ({
            from,
            to,
            master: transformNode(master),
            replicas: replicas.map(transformNode)
        }));
    }
};
function transformNode(node) {
    const [host, port, id] = node;
    return {
        host,
        port,
        id
    };
}
//# sourceMappingURL=CLUSTER_SLOTS.js.map