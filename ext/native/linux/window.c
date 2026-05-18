#include <gtk/gtk.h>
#include <pthread.h>

// GTK window operations require the main thread.  Binding callbacks may arrive
// on any Crystal fiber thread, so we dispatch synchronously when needed.

typedef struct { int x; int y; int width; int height; } WindowFrame;

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

// ── Impl structs & functions ──────────────────────────────────────────────────

typedef struct { void *win; const char *title; } TitleArgs;
typedef struct { void *win; int w; int h; } SizeArgs;
typedef struct { void *win; int x; int y; int w; int h; } FrameArgs;
typedef struct { void *win; WindowFrame result; } GetFrameArgs;

static void _minimize_impl(void *p)   { gtk_window_iconify(GTK_WINDOW(p)); }
static void _maximize_impl(void *p)   { gtk_window_maximize(GTK_WINDOW(p)); }

static void _set_title_impl(void *p) {
    TitleArgs *a = p;
    gtk_window_set_title(GTK_WINDOW(a->win), a->title);
}

static void _set_size_impl(void *p) {
    SizeArgs *a = p;
    gtk_window_resize(GTK_WINDOW(a->win), a->w, a->h);
}

static void _center_impl(void *p) {
    gtk_window_set_position(GTK_WINDOW(p), GTK_WIN_POS_CENTER);
}

static void _get_frame_impl(void *p) {
    GetFrameArgs *a = p;
    gtk_window_get_position(GTK_WINDOW(a->win), &a->result.x, &a->result.y);
    gtk_window_get_size(GTK_WINDOW(a->win), &a->result.width, &a->result.height);
}

static void _set_frame_impl(void *p) {
    FrameArgs *a = p;
    gtk_window_move(GTK_WINDOW(a->win), a->x, a->y);
    gtk_window_resize(GTK_WINDOW(a->win), a->w, a->h);
}

// ── Public API ────────────────────────────────────────────────────────────────

void minimize(void *window) { run_on_main(_minimize_impl, window); }
void maximize(void *window) { run_on_main(_maximize_impl, window); }

void set_title(void *window, const char *title) {
    TitleArgs a = {window, title};
    run_on_main(_set_title_impl, &a);
}

void set_size(void *window, int width, int height) {
    SizeArgs a = {window, width, height};
    run_on_main(_set_size_impl, &a);
}

void center(void *window) { run_on_main(_center_impl, window); }

WindowFrame get_frame(void *window) {
    GetFrameArgs a = {window, {0, 0, 0, 0}};
    run_on_main(_get_frame_impl, &a);
    return a.result;
}

void set_frame(void *window, int x, int y, int width, int height) {
    FrameArgs a = {window, x, y, width, height};
    run_on_main(_set_frame_impl, &a);
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
    if (_pos_cb) _pos_cb(-1, -1, _pos_userdata);

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
    // WebKitWebView on Linux does not navigate on file drop by default.
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
