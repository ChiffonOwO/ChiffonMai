export default class Node {
    depth = 0;
    key;
    word = false;
    children = {};
    fail;
    count = 0;
    constructor(key, depth = 0) {
        this.key = key;
        this.depth = depth;
    }
}
