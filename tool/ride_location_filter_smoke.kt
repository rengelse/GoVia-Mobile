package no.govia.mobile.car
fun main() {
    val now = 1_000_000L
    val f = RideLocationFilter { now }
    check(f.accept(RideLocationSample("gps",58.9700,5.7300,now-5000,5f)))
    check(!f.accept(RideLocationSample("network",58.9702,5.7300,now-3000,10f)))
    check(!f.accept(RideLocationSample("gps",59.2000,5.7300,now-2000,5f)))
    println("PASS RideLocationFilter")
}
