package no.govia.mobile.car

import androidx.car.app.model.ActionStrip

/**
 * Android Auto template compatibility helpers.
 *
 * NavigationTemplate requires a non-null ActionStrip, while the GoVia surface owns the
 * visible controls. Returning the protocol-serialization empty model avoids asking the host
 * to render an extra floating action button on top of the GoVia UI.
 */
internal object GoViaCarTemplateCompat {
    fun invisibleRequiredActionStrip(): ActionStrip {
        val constructor = ActionStrip::class.java.getDeclaredConstructor()
        constructor.isAccessible = true
        return constructor.newInstance()
    }
}
