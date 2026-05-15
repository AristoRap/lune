#include <gtk/gtk.h>

void screen_info(int *width, int *height, double *scale) {
    GdkDisplay *display = gdk_display_get_default();
    GdkMonitor *monitor = gdk_display_get_primary_monitor(display);

    GdkRectangle geometry;
    gdk_monitor_get_geometry(monitor, &geometry);

    *width  = geometry.width;
    *height = geometry.height;
    *scale  = (double)gdk_monitor_get_scale_factor(monitor);
}
