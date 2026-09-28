function dmSeqKey(conversationId) {
  return `dm:${conversationId}:seq`;
}
async function nextDmSeq(redis, conversationId) {
  if (!conversationId) return 0;
  return redis.incr(dmSeqKey(conversationId));
}
module.exports = { dmSeqKey: dmSeqKey, nextDmSeq: nextDmSeq };
