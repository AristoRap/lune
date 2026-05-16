#include <gtk/gtk.h>

typedef struct { int x; int y; int width; int height; } WindowFrame;

void minimize(void *window) {
    gtk_window_iconify(GTK_WINDOW(window));
}

void maximize(void *window) {
    gtk_window_maximize(GTK_WINDOW(window));
}

void set_title(void *window, const char *title) {
    gtk_window_set_title(GTK_WINDOW(window), title);
}

void set_size(void *window, int width, int height) {
    gtk_window_resize(GTK_WINDOW(window), width, height);
}

void center(void *window) {
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
}

WindowFrame get_frame(void *window) {
    GtkWindow *w = GTK_WINDOW(window);
    WindowFrame f;
    gtk_window_get_position(w, &f.x, &f.y);
    gtk_window_get_size(w, &f.width, &f.height);
    return f;
}

void set_frame(void *window, int x, int y, int width, int height) {
    GtkWindow *w = GTK_WINDOW(window);
    gtk_window_move(w, x, y);
    gtk_window_resize(w, width, height);
}

// ── File drop ─────────────────────────────────────────────────────────────────

typedef void (*LuneDropCallback)(const char *json, void *userdata);
typedef void (*LuneDragPosCallback)(int x, int y, void *userdata);

static LuneDropCallback    _drop_cb       = NULL;
static void               *_drop_userdata = NULL;
static LuneDragPosCallback _pos_cb        = NULL;
static void               *_pos_userdata  = NULL;

static void on_drag_motion(GtkWidget *widget, GdkDragContext *context,
                            int x, int y, guint time, gpointer user_data) {
    gdk_drag_status(context, GDK_ACTION_COPY, time);
    if (_pos_cb) _pos_cb(x, y, _pos_userdata);
}

static void on_drag_leave(GtkWidget *widget, GdkDragContext *context,
                           guint time, gpointer user_data) {
    if (_pos_cb) _pos_cb(-1, -1, _pos_userdata);
}

static void on_drag_data_received(GtkWidget *widget, GdkDragContext *context,
                                   int x, int y, GtkSelectionData *data,
                                   guint info, guint time, gpointer user_data) {
    if (_pos_cb) _pos_cb(-1, -1, _pos_userdata); // clear zones on drop

    gchar **uris = gtk_selection_data_get_uris(data);
    if (!uris) {
        gtk_drag_finish(context, FALSE, FALSE, time);
        return;
    }

    GString  *paths = g_string_new("[");
    gboolean  first = TRUE;
    for (int i = 0; uris[i] != NULL; i++) {
        gchar *path = g_filename_from_uri(uris[i], NULL, NULL);
        if (!path) continue;
        gchar *escaped = g_strescape(path, NULL);
        if (!first) g_string_append(paths, ",");
        first = FALSE;
        g_string_append_printf(paths, "\"%s\"", escaped);
        g_free(escaped);
        g_free(path);
    }
    g_strfreev(uris);
    g_string_append(paths, "]");

    gchar *json = g_strdup_printf("{\"x\":%d,\"y\":%d,\"paths\":%s}", x, y, paths->str);
    g_string_free(paths, TRUE);

    if (_drop_cb) _drop_cb(json, _drop_userdata);
    g_free(json);
    gtk_drag_finish(context, TRUE, FALSE, time);
}

void disable_webview_drop(void *window) {
    // WebKitWebView on Linux does not navigate on file drop by default,
    // so this is a no-op. Reserved for future hardening if needed.
    (void)window;
}

void setup_file_drop(void *window,
                     LuneDropCallback    drop_callback,  void *drop_userdata,
                     LuneDragPosCallback pos_callback,   void *pos_userdata) {
    _drop_cb       = drop_callback;
    _drop_userdata = drop_userdata;
    _pos_cb        = pos_callback;
    _pos_userdata  = pos_userdata;

    GtkWidget *target = GTK_IS_BIN(window)
                        ? gtk_bin_get_child(GTK_BIN(window))
                        : GTK_WIDGET(window);
    if (!target) target = GTK_WIDGET(window);

    GtkTargetEntry targets[] = {{"text/uri-list", 0, 0}};
    gtk_drag_dest_set(target, GTK_DEST_DEFAULT_DROP, targets, 1, GDK_ACTION_COPY);
    g_signal_connect(target, "drag-motion",        G_CALLBACK(on_drag_motion),        NULL);
    g_signal_connect(target, "drag-leave",         G_CALLBACK(on_drag_leave),         NULL);
    g_signal_connect(target, "drag-data-received", G_CALLBACK(on_drag_data_received), NULL);
}
