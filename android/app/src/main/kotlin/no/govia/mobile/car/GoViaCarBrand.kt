package no.govia.mobile.car

import androidx.car.app.CarContext
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.core.graphics.drawable.IconCompat

internal object GoViaCarBrand {
    val ORANGE: CarColor = CarColor.createCustom(0xFFFF7E16.toInt(), 0xFFFF9A45.toInt())

    fun icon(carContext: CarContext, drawable: Int, tinted: Boolean = true): CarIcon {
        val builder = CarIcon.Builder(IconCompat.createWithResource(carContext, drawable))
        if (tinted) builder.setTint(CarColor.PRIMARY)
        return builder.build()
    }
}
