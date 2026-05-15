#include <gtk/gtk.h>
#include <string.h>

/*
 * Uses GtkStatusIcon (deprecated since GTK 3.14 but functional on all GTK3
 * systems). Requires XWayland on Wayland compositors — pure Wayland sessions
 * will not show the icon.
 */

typedef void (*LuneTrayCallback)(void *);
typedef void (*LuneMenuCallback)(const char *, void *);

static GtkStatusIcon    *_icon       = NULL;
static GtkWidget        *_menu       = NULL;
static LuneTrayCallback  _click_cb   = NULL;
static void             *_click_data = NULL;
static LuneMenuCallback  _menu_cb    = NULL;
static void             *_menu_data  = NULL;

static void on_activate(GtkStatusIcon *icon, gpointer data) {
    (void)icon; (void)data;
    if (_click_cb) _click_cb(_click_data);
}

static void on_popup_menu(GtkStatusIcon *icon, guint button, guint activate_time, gpointer data) {
    (void)data;
    if (_menu) {
        gtk_menu_popup(GTK_MENU(_menu), NULL, NULL,
                       gtk_status_icon_position_menu, icon,
                       button, activate_time);
    }
}

static void on_menu_item_activate(GtkMenuItem *item, gpointer data) {
    (void)data;
    const char *id = g_object_get_data(G_OBJECT(item), "lune-id");
    if (_menu_cb && id) _menu_cb(id, _menu_data);
}

static void ensure_icon(void) {
    if (!_icon) {
        _icon = gtk_status_icon_new();
        g_signal_connect(_icon, "activate",   G_CALLBACK(on_activate),   NULL);
        g_signal_connect(_icon, "popup-menu", G_CALLBACK(on_popup_menu), NULL);
    }
}

static void apply_icon(const char *icon_path) {
    if (icon_path && icon_path[0]) {
        gtk_status_icon_set_from_file(_icon, icon_path);
    } else {
        gtk_status_icon_set_from_icon_name(_icon, "application-x-executable");
    }
}

void tray_show(const char *icon_path, LuneTrayCallback callback, void *userdata) {
    ensure_icon();
    _click_cb   = callback;
    _click_data = userdata;
    apply_icon(icon_path);
    gtk_status_icon_set_visible(_icon, TRUE);
}

void tray_hide(void) {
    if (_icon) gtk_status_icon_set_visible(_icon, FALSE);
}

void tray_set_icon(const char *icon_path) {
    if (!_icon) return;
    apply_icon(icon_path);
}

void tray_set_menu(const char **ids, const char **labels, int count,
                   LuneMenuCallback callback, void *userdata) {
    ensure_icon();
    _menu_cb   = callback;
    _menu_data = userdata;

    if (_menu) gtk_widget_destroy(_menu);
    _menu = gtk_menu_new();

    for (int i = 0; i < count; i++) {
        GtkWidget *item;
        if (strcmp(ids[i], "---") == 0) {
            item = gtk_separator_menu_item_new();
        } else {
            item = gtk_menu_item_new_with_label(labels[i]);
            g_object_set_data_full(G_OBJECT(item), "lune-id", g_strdup(ids[i]), g_free);
            g_signal_connect(item, "activate", G_CALLBACK(on_menu_item_activate), NULL);
        }
        gtk_menu_shell_append(GTK_MENU_SHELL(_menu), item);
    }

    gtk_widget_show_all(_menu);
    /* Attaching a menu disables direct click — mirrors macOS behaviour */
    _click_cb = NULL;
    gtk_status_icon_set_visible(_icon, TRUE);
}
