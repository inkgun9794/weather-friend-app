package com.weatherfriend.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the current weather. Data is written by the
 * Flutter side (WeatherWidgetService) into the home_widget SharedPreferences;
 * here we just render it. Static illustration per condition — no animation, in
 * line with Android App Widget constraints.
 */
class WeatherWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.weather_widget).apply {
                val city = widgetData.getString("city", "날씨") ?: "날씨"
                val temp = widgetData.getString("temp", "--°") ?: "--°"
                val condition = widgetData.getString("condition", "clear") ?: "clear"
                val isDay = widgetData.getBoolean("isDay", true)
                val precip = widgetData.getString("precip", "") ?: ""
                val outfit = widgetData.getString("outfit", "") ?: ""

                setTextViewText(R.id.widget_city, city)
                setTextViewText(R.id.widget_temp, temp)
                setTextViewText(R.id.widget_precip, precip)
                setImageViewResource(R.id.widget_icon, iconFor(condition, isDay))
                setInt(R.id.widget_root, "setBackgroundResource", bgFor(condition, isDay))
                applyOutfit(context, this, outfit)

                // Tap the widget → open the app.
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** Fills up to 3 outfit ImageViews from a comma-separated key list
     *  (e.g. "coat,scarf,umbrella"); each maps to drawable `oc_<key>`.
     *  Unused slots are hidden. */
    private fun applyOutfit(context: Context, views: RemoteViews, outfit: String) {
        val slots = intArrayOf(
            R.id.widget_outfit_0,
            R.id.widget_outfit_1,
            R.id.widget_outfit_2,
        )
        val keys = outfit.split(',')
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .take(slots.size)
        slots.forEachIndexed { i, slotId ->
            val key = keys.getOrNull(i)
            val resId = if (key == null) 0 else context.resources.getIdentifier(
                "oc_$key", "drawable", context.packageName,
            )
            if (resId != 0) {
                views.setImageViewResource(slotId, resId)
                views.setViewVisibility(slotId, View.VISIBLE)
            } else {
                views.setViewVisibility(slotId, View.GONE)
            }
        }
    }

    private fun iconFor(condition: String, isDay: Boolean): Int = when (condition) {
        "rain" -> R.drawable.wx_rain
        "snow" -> R.drawable.wx_snow
        "cloudy" -> R.drawable.wx_cloudy
        else -> if (isDay) R.drawable.wx_clear_day else R.drawable.wx_clear_night
    }

    private fun bgFor(condition: String, isDay: Boolean): Int = when (condition) {
        "rain", "snow" -> R.drawable.widget_bg_overcast
        "cloudy" -> R.drawable.widget_bg_cloudy
        else -> if (isDay) R.drawable.widget_bg_day else R.drawable.widget_bg_night
    }
}
