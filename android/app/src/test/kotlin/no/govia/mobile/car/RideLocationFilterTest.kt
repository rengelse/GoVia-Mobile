package no.govia.mobile.car

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RideLocationFilterTest {
    private val now = 1_000_000L

    private fun sample(
        provider: String = "gps",
        lat: Double = 58.9700,
        lon: Double = 5.7300,
        timeMs: Long = now,
        accuracy: Float = 5f,
    ) = RideLocationSample(provider, lat, lon, timeMs, accuracy)

    @Test
    fun `rejects stale inaccurate and implausible jump fixes`() {
        val filter = RideLocationFilter { now }
        assertFalse(filter.accept(sample(timeMs = now - 20_000)))
        assertFalse(filter.accept(sample(accuracy = 80f)))
        assertTrue(filter.accept(sample(timeMs = now - 5_000)))
        assertFalse(filter.accept(sample(lat = 59.20, lon = 5.73, timeMs = now - 3_000)))
    }

    @Test
    fun `suppresses network fixes while fresh gps track exists`() {
        val filter = RideLocationFilter { now }
        assertTrue(filter.accept(sample(timeMs = now - 5_000)))
        assertFalse(filter.accept(sample(provider = "network", lat = 58.9702, timeMs = now - 3_000, accuracy = 10f)))
    }

    @Test
    fun `accepts plausible ordered gps movement`() {
        val filter = RideLocationFilter { now }
        assertTrue(filter.accept(sample(timeMs = now - 5_000)))
        assertTrue(filter.accept(sample(lat = 58.9702, timeMs = now - 2_000)))
    }
}
