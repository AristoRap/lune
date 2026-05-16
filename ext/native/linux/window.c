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

typedef void (*LuneDropCallback)(const char *paths_json, void *userdata);

static LuneDropCallback _drop_cb       = NULL;
static void            *_drop_userdata = NULL;

static void on_drag_data_received(GtkWidget *widget, GdkDragContext *context,
                                   int x, int y, GtkSelectionData *data,
                                   guint info, guint time, gpointer user_data) {
    gchar **uris = gtk_selection_data_get_uris(data);
    if (!uris) {
        gtk_drag_finish(context, FALSE, FALSE, time);
        return;
    }

    GString  *json  = g_string_new("[");
    gboolean  first = TRUE;
    for (int i = 0; uris[i] != NULL; i++) {
        gchar *path = g_filename_from_uri(uris[i], NULL, NULL);
        if (!path) continue;
        gchar *escaped = g_strescape(path, NULL);
        if (!first) g_string_append(json, ",");
        first = FALSE;
        g_string_append_printf(json, "\"%s\"", escaped);
        g_free(escaped);
        g_free(path);
    }
    g_strfreev(uris);
    g_string_append(json, "]");

    if (_drop_cb) _drop_cb(json->str, _drop_userdata);
    g_string_free(json, TRUE);
    gtk_drag_finish(context, TRUE, FALSE, time);
}

void setup_file_drop(void *window, LuneDropCallback callback, void *userdata) {
    _drop_cb       = callback;
    _drop_userdata = userdata;

    // Register on the webview widget (direct child of the window) so it sits
    // on top and receives drops before the window's background.
    GtkWidget *target = GTK_IS_BIN(window)
                        ? gtk_bin_get_child(GTK_BIN(window))
                        : GTK_WIDGET(window);
    if (!target) target = GTK_WIDGET(window);

    GtkTargetEntry targets[] = {{"text/uri-list", 0, 0}};
    gtk_drag_dest_set(target, GTK_DEST_DEFAULT_ALL, targets, 1, GDK_ACTION_COPY);
    g_signal_connect(target, "drag-data-received",
                     G_CALLBACK(on_drag_data_received), NULL);
}
