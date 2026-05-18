#include <gtk/gtk.h>
#include <pthread.h>
#include <string.h>

/*
 * Uses GtkStatusIcon (deprecated since GTK 3.14 but functional on all GTK3
 * systems). Requires XWayland on Wayland compositors — pure Wayland sessions
 * will not show the icon.
 *
 * GTK requires UI calls on the main thread. Binding callbacks may arrive on
 * any Crystal fiber thread, so we dispatch synchronously when needed.
 */

typedef void (*LuneTrayCallback)(void *);
typedef void (*LuneMenuCallback)(const char *, void *);

static GtkStatusIcon    *_icon       = NULL;
static GtkWidget        *_menu       = NULL;
static LuneTrayCallback  _click_cb   = NULL;
static void             *_click_data = NULL;
static LuneMenuCallback  _menu_cb    = NULL;
static void             *_menu_data  = NULL;

// ── Main-thread dispatcher ────────────────────────────────────────────────────

static pthread_t      _main_tid;
static pthread_once_t _once = PTHREAD_ONCE_INIT;
static void _capture(void) { _main_tid = pthread_self(); }

typedef struct { void (*fn)(void *); void *d; GMutex m; GCond c; gboolean done; } _Call;

static gboolean _call_cb(gpointer p) {
    _Call *c = p;
    c->fn(c->d);
    g_mutex_lock(&c->m);
    c->done = TRUE;
    g_cond_signal(&c->c);
    g_mutex_unlock(&c->m);
    return G_SOURCE_REMOVE;
}

static void run_on_main(void (*fn)(void *), void *d) {
    pthread_once(&_once, _capture);
    if (pthread_equal(pthread_self(), _main_tid)) { fn(d); return; }
    _Call c = {.fn = fn, .d = d, .done = FALSE};
    g_mutex_init(&c.m); g_cond_init(&c.c);
    g_idle_add(_call_cb, &c);
    g_mutex_lock(&c.m);
    while (!c.done) g_cond_wait(&c.c, &c.m);
    g_mutex_unlock(&c.m);
    g_mutex_clear(&c.m); g_cond_clear(&c.c);
}

// ── GTK event callbacks (always on main thread) ───────────────────────────────

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
    if (icon_path && icon_path[0])
        gtk_status_icon_set_from_file(_icon, icon_path);
    else
        gtk_status_icon_set_from_icon_name(_icon, "application-x-executable");
}

// ── Impl structs ──────────────────────────────────────────────────────────────

typedef struct { const char *icon_path; LuneTrayCallback cb; void *ud; } ShowArgs;
typedef struct { const char **ids; const char **labels; int count;
                 LuneMenuCallback cb; void *ud; } MenuArgs;

static void _tray_show_impl(void *p) {
    ShowArgs *a = p;
    ensure_icon();
    apply_icon(a->icon_path);
    gtk_status_icon_set_visible(_icon, TRUE);
}

static void _tray_hide_impl(void *p) {
    (void)p;
    if (_icon) gtk_status_icon_set_visible(_icon, FALSE);
}

static void _tray_set_icon_impl(void *p) {
    apply_icon((const char *)p);
}

static void _tray_set_menu_impl(void *p) {
    MenuArgs *a = p;
    ensure_icon();
    if (_menu) gtk_widget_destroy(_menu);
    _menu = gtk_menu_new();
    for (int i = 0; i < a->count; i++) {
        GtkWidget *item;
        if (strcmp(a->ids[i], "---") == 0) {
            item = gtk_separator_menu_item_new();
        } else {
            item = gtk_menu_item_new_with_label(a->labels[i]);
            g_object_set_data_full(G_OBJECT(item), "lune-id", g_strdup(a->ids[i]), g_free);
            g_signal_connect(item, "activate", G_CALLBACK(on_menu_item_activate), NULL);
        }
        gtk_menu_shell_append(GTK_MENU_SHELL(_menu), item);
    }
    gtk_widget_show_all(_menu);
    _click_cb = NULL;
    gtk_status_icon_set_visible(_icon, TRUE);
}

// ── Public API ────────────────────────────────────────────────────────────────

void tray_show(const char *icon_path, LuneTrayCallback callback, void *userdata) {
    _click_cb   = callback;
    _click_data = userdata;
    ShowArgs a  = {icon_path, callback, userdata};
    run_on_main(_tray_show_impl, &a);
}

void tray_hide(void) {
    run_on_main(_tray_hide_impl, NULL);
}

void tray_set_icon(const char *icon_path) {
    if (!_icon) return;
    run_on_main(_tray_set_icon_impl, (void *)(uintptr_t)icon_path);
}

void tray_set_menu(const char **ids, const char **labels, int count,
                   LuneMenuCallback callback, void *userdata) {
    _menu_cb   = callback;
    _menu_data = userdata;
    MenuArgs a = {ids, labels, count, callback, userdata};
    run_on_main(_tray_set_menu_impl, &a);
}
