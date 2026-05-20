#include <libnotify/notify.h>

void show_notification(const char *title, const char *body) {
    if (!notify_is_initted()) {
        notify_init("lune");
    }
    NotifyNotification *notif = notify_notification_new(title, body, NULL);
    notify_notification_show(notif, NULL);
    g_object_unref(notif);
}
