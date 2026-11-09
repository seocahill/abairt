package com.abairt.listen.playback

/**
 * The bookkeeping of a radio that never runs out: when to ask for more, which
 * recordings not to ask for again, how much of what has been heard to keep so
 * "previous" still works. No Android in here, so it can be tested on the JVM.
 */
class RadioQueue(
    private val prefetchAhead: Int = 2,
    private val keepHistory: Int = 3,
    private val excludeLimit: Int = 100,
    val batchSize: Int = 5,
) {
    private val queued = ArrayDeque<Long>()

    fun reset() = queued.clear()

    /** Note recordings as queued, so they are not offered again soon. */
    fun queued(ids: List<Long>) {
        queued.addAll(ids)
        while (queued.size > excludeLimit) queued.removeFirst()
    }

    /** The ids to leave out of the next request (the most recent ones, to keep the URL short). */
    fun excludeIds(): List<Long> = queued.toList()

    /** True when fewer than [prefetchAhead] recordings are waiting after the current one. */
    fun shouldLoadMore(currentIndex: Int, count: Int): Boolean =
        count == 0 || count - currentIndex - 1 < prefetchAhead

    /** How many played items to drop from the front of the playlist. */
    fun itemsToTrim(currentIndex: Int): Int = (currentIndex - keepHistory).coerceAtLeast(0)
}
